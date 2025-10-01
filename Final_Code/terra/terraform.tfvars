/*
- 사용자가 변수의 값을 특정하고 싶을 때, .tfvars 파일을 사용할 수 있다
- 이때 파일명이 terraform 이 아닐 경우 자동으로 인식되지는 않고 -var-file=임의설정이름.tfvars 와 같이 옵션을 추가해줘야 한다.
- E.g, terraform -apply -var-file=abc.tfvar 

- ⚠️ 클러스터 이름에 대문자 들어가면 안됨!!!!!⚠️
*/
key_pair_name = "LetMeIn"
cluster_name  = "my-eks-shop-cluster"

# RDS master password (for demonstration purposes; replace with a strong password)
db_master_password = "passWord"
