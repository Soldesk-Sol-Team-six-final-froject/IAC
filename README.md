# Guideline
## 실행 순서 

1. 부트스트랩 스크립트 실행 <p>  `bash bootstrap.sh`
2. 스크립트 실행 후 출력된 결과에 나온 Bastion IP주소 입력하여 SSH 접속 후
    1. `0_Setup_autocomplete .sh`
    2. `1_CONFIG-ECR.sh` 
    3. `2_DB-NS-SETUP.sh`
    4. `3_ARGO-INSTALL.sh`
    5. `4_LBC.sh`
    6. 이후 `kubectl apply -f ./k8s/ingress.yaml` 으로 인그레스 생성 
    7. 마지막으로 `5_Route53.sh` 실행 

## 예상 결과
- Route53에 특정 도메인(www.example.com)이 A Record로 등록되어서, 해당 도메인으로 본인이 원하는 서비스(Pod)로 접근 가능함 [사전에 Argo가 Manifest들을 참조하여 deployments 등 리소스 배포를 할 수 있도록 해야 함 ➡️ 동엽님 문의 ]


## 개선점 
- Argo, ALB 등의 생성 및 초기 설정까지 Terraform 코드로 추가해 줄 수 있음 
- 현재는 Cognito 관련 내용이 주석처리되어 있음(ingress.yaml 참조), 삭제 혹은 생성 후 값 수정하여 사용할 수 있음

## 주의사항
- ⚠️ 작업 위치를(초기 스크립트 실행 할) 준수할 것  
    - `/Final_Code` 
- 사전에 연결된 AWS 계정정보 확인(부트스트랩 스크립트 실행할 쉘에 설정된 값을 의미함) 
    - `aws sts get-caller-identity` 입력 후 원하는 계정에 연결되어 있는지 확인할 것
- Route53 서비스의 Hosted Zone(Public) 생성 및 원하는 도메인 등록은 사전에 수동으로 해야 함    
    - 이때 Gabia 등 에서 발급받은 고유 도메인에 대한 네임 서버를, AWS가 제공하는 네임서버로 지정해주어야 함 