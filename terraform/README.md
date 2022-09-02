### Create infrastructure with terraform (WIP)

- Things to automate:
  - setup password of the default `postgres` user: at the moment, we change them manually and terraform does not detect any state change.
  
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
