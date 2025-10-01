#!/bin/bash
#set -euo pipefail # -e: 명령어 실패 시 종료, -u: 정의되지 않은 변수 사용 시 오류 발생, -o pipefail: 파이프라인 내 명령어 실패 시 전체 파이프라인 실패로 간주

# Color definitions
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Required environment variables check
required_vars=(
    "DB_MASTER_USERNAME"
    "DB_MASTER_PASSWORD"
    "RDS_ENDPOINT"
    "DB_NAME"
    "REDIS_ENDPOINT"
)

for var in "${required_vars[@]}"; do # required_vars 배열의 각 요소에 대해 반복
    if [ -z "${!var:-}" ]; then # -z: 문자열 길이가 0인지 확인, 즉, 변수가 비어있는지 확인, !var: 변수의 이름을 동적으로 역참조(& in C) -> var가 또 다른 변수에 대한 포인터일 경우, 계속 참조함  
        echo -e "${RED}Error: Required variable $var is not set${NC}" # -e: 이스케이프 문자 해석
        exit 1
    fi
done

# Function to safely create namespace and service account
create_ns_sa() {
    echo -e "${GREEN}[1/3] Setting up namespace and service account...${NC}"

    if ! kubectl get ns shop >/dev/null 2>&1; then # 해당 네임스페이스가 없을 때만 생성 , 존재하면 0 반환 -> ! 를 사용하여 존재하지 않을 때에만 실행
        echo -e "${GREEN}Creating namespace: shop${NC}"
        kubectl create namespace shop
    fi

    if ! kubectl get serviceaccount shopping-mall-sa -n shop >/dev/null 2>&1; then # 해당 서비스 어카운트가 없을 때만 생성
        echo -e "${GREEN}Creating service account: shopping-mall-sa${NC}"
        kubectl create serviceaccount shopping-mall-sa -n shop
    fi
}

# Function to create and validate secrets
create_secrets() {
    echo -e "${GREEN}[2/3] Creating secrets...${NC}"
    local db_uri="mysql+pymysql://${DB_MASTER_USERNAME}:${DB_MASTER_PASSWORD}@${RDS_ENDPOINT}:3306/${DB_NAME}?charset=utf8mb4"
    local redis_url="redis://${REDIS_ENDPOINT}:6379"
    
    # Generate JWT secret if not provided
    if [[ -z "${JWT_SECRET_KEY:-}" ]]; then # -z: 문자열 길이가 0인지 확인, 즉, 변수가 비어있는지 확인
        JWT_SECRET_KEY=$(openssl rand -base64 32) # OpenSSL을 사용하여 32바이트 길이의 랜덤 바이트를 생성하고, 이를 base64로 인코딩
    fi

    # Validate connection strings
    if [[ ! "$db_uri" =~ ^mysql\+pymysql:// ]]; then # =~: 정규표현식 매칭 연산자, ^: 문자열 시작, \+: + 문자를 이스케이프, .: 임의의 문자, *: 0회 이상 반복
        echo -e "${RED}Error: Invalid DB_URI format${NC}" # 반드시 시작을 mysql+pymysql://로 해야함
        exit 1
    fi

    if [[ ! "$redis_url" =~ ^redis:// ]]; then
        echo -e "${RED}Error: Invalid REDIS_URL format${NC}"
        exit 1
    fi

    echo -e "${GREEN}Creating/updating shop-secrets...${NC}"
    kubectl delete secret shop-secrets -n shop >/dev/null 2>&1 || true # 기존 시크릿이 있으면 삭제, 없으면 무시하고 계속 진행
    
    if ! kubectl create secret generic shop-secrets -n shop \
        --from-literal=DB_URI="$db_uri" \
        --from-literal=REDIS_URL="$redis_url" \
        --from-literal=JWT_SECRET_KEY="$JWT_SECRET_KEY"; then
        echo -e "${RED}Failed to create secrets${NC}"
        exit 1
    fi

    echo -e "${GREEN}Secrets created successfully${NC}"
}

# Function to setup database
setup_database() {
    echo -e "${GREEN}[3/3] Setting up database...${NC}"
    
    # Check MySQL client
    if ! command -v mysql &>/dev/null; then # command -v [@]: 명령어가 시스템에 존재하는지 확인, 경로를 출력하면 성공(0), 존재하지 않으면 실패(1)
        echo -e "${YELLOW}Installing MySQL client...${NC}"
        sudo yum install -y mysql
    fi

    # Test connection
    if ! mysql -h "$RDS_ENDPOINT" -u "$DB_MASTER_USERNAME" -p"$DB_MASTER_PASSWORD" \
        -e "SELECT 1;" >/dev/null 2>&1; then # SELECT 1; 쿼리를 실행하여 연결 테스트, 성공 시 0 반환 -> ! 를 사용하여 실패했을 때에만 실행
        echo -e "${RED}Cannot connect to database${NC}"
        exit 1
    fi

    # Create database if not exists
    echo "Creating database if not exists..."
    mysql -h "$RDS_ENDPOINT" -u "$DB_MASTER_USERNAME" -p"$DB_MASTER_PASSWORD" \
        -e "CREATE DATABASE IF NOT EXISTS $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" # SQL 구문으로 존재하지 않을 경우에만 생성보장

    # Create tables using SQL file if exists
    SQL_FILE="./sql/init.sql"
    if [ -f "$SQL_FILE" ]; then
        echo "Initializing database schema..."
        mysql -h "$RDS_ENDPOINT" -u "$DB_MASTER_USERNAME" -p"$DB_MASTER_PASSWORD" \
            "$DB_NAME" < "$SQL_FILE"
    else
        echo -e "${YELLOW}Warning: $SQL_FILE not found, skipping schema initialization${NC}"
    fi
}

# Main execution, 위에서 설정한 함수들 순차적 실행 
echo -e "${GREEN}Starting setup process...${NC}"

create_ns_sa
create_secrets
setup_database

echo -e "${GREEN}All resources created successfully${NC}"