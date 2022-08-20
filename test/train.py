import os
import numpy as np
from sklearn.linear_model import LogisticRegression

import mlflow
import mlflow.sklearn

try_to_log_to_remote_server = True
direct_gcs_access = True

if direct_gcs_access:
    os.environ['GOOGLE_APPLICATION_CREDENTIALS'] = os.environ['GCS_CREDENTIALS']

if try_to_log_to_remote_server:
    mlflow.set_tracking_uri("http://127.0.0.1:8080")
    mlflow.set_experiment("ex_001")

if __name__ == "__main__":
    X = np.array([-2, -1, 0, 1, 2, 1]).reshape(-1, 1)
    y = np.array([0, 0, 1, 1, 1, 0])
    lr = LogisticRegression()
    lr.fit(X, y)
    score = lr.score(X, y)
    print("Score: %s" % score)
    mlflow.log_metric("score", score)
    mlflow.sklearn.log_model(lr, "model")
    print("Model saved in run %s" % mlflow.active_run().info.run_uuid)
