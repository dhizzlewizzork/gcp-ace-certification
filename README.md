# gcp-ace-certification

## Overview

This document provides instructions on how to use the Terraform modules that have been written for each lab. The Terraform modules are designed to simplify the process of setting up and managing the infrastructure required for the labs in the GCP ACE Certification course. By following the instructions in this document, users will be able to easily deploy and configure the necessary resources in their GCP environment, enabling them to complete the labs efficiently and effectively.

## How to use

1. Navigate to folder aligning with your lab.
2. Populate `terraform.tfvars`

    This will include any dynamically generated information in the labs like `project_id`, `region`, `zone`, or any naming variables.

3. Login via `gcloud`

    Run the following:
    ```shell
    gcloud auth application-default login
    ```
    Copy the link it gives to you to your incognito window with your student login to login properly.

4. Run terraform as usual

    ```shell
    terraform init
    terraform plan -out tfplan
    terraform apply tfplan
    ```
