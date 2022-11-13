### Create infrastructure with terraform
  
- Install the terraform version manager. We will work with version `1.2.7`: 
  ```shell
  tfenv install 1.2.7
  tfenv use 1.2.7
  ```

- Set the `project`, `region` and `zone` in `variables.tf` and authenticate:
  ```shell
  gcloud init
  gcloud auth application-default login
  
  terraform init
  terraform fmt
  ```
