### mlflow server

- Create a container that is running the mlflow server.
  ```shell
  docker build -t imscientist/mlflow:0.1 .
  ```

- Test it with:
  ```shell
  docker run -it --rm --name mlflow_test -p 5000:5000 \
    imscientist/mlflow:0.1 /bin/bash -c "mlflow server --host 0.0.0.0"
  ```
