# Check The $<...> REGION, ECR_REGISTRY
# 정상적으로 ECR 레지스트리가 생성되었는지 확인하고, 없으면 생성함, 로그인 가능여부 확인

aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME" --alias "$CLUSTER_NAME"
# 현재 설정한 리젼, 클러스터 이름으로 kubeconfig 파일을 업데이트, --alias 옵션은 클러스터에 대한 별칭을 지정
aws ecr get-login-password --region "$REGION" | sudo docker login --username AWS --password-stdin "$ECR_REGISTRY"
# ECR 레지스트리에 로그인, get-login-password 명령어로 인증 토큰을 가져와서 도커 로그인에 사용
if ! aws ecr describe-repositories --repository-names shop-backend --region "$REGION" >/dev/null 2>&1; then # ECR 존재 시 0반환 -> ! 를 사용하여 존재하지 않을 때에만 실행
  aws ecr create-repository --repository-name shop-backend --region "$REGION"
fi
if ! aws ecr describe-repositories --repository-names shop-frontend --region "$REGION" >/dev/null 2>&1; then
  aws ecr create-repository --repository-name shop-frontend --region "$REGION"
fi

