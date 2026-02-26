# Complete Line-by-Line Explanation: Terraform + Jenkins Pipeline

## 📄 MAIN.TF (Terraform Configuration)

### Block 1: Terraform Settings
```hcl
terraform {
  required_version = ">= 1.5"
}
```
- `terraform {}` — The root configuration block for Terraform itself
- `required_version = ">= 1.5"` — This project refuses to run on Terraform older than v1.5. Prevents bugs from outdated syntax

```hcl
required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}
```
- `required_providers` — Declares external plugins Terraform needs to download
- `docker` — We're naming this provider "docker" (we reference it later)
- `source = "kreuzwerker/docker"` — Download from the Terraform Registry. Path = registry.terraform.io/kreuzwerker/docker
- `version = "~> 3.0"` — Allow 3.x (3.0, 3.1, 3.9...) but NOT 4.0. The ~> means "pessimistic constraint"

### Block 2: Provider Configuration
```hcl
provider "docker" {
  host = "unix:///var/run/docker.sock"
}
```
- `provider "docker"` — Configures HOW Terraform talks to Docker
- `host = "unix:///var/run/docker.sock"` — Connect via Unix socket (the local Docker daemon). This is how CLI commands like `docker ps` work under the hood
- On Windows this would be `npipe:////./pipe/docker_engine`

### Block 3: Variables (Inputs)
```hcl
variable "docker_image" {
  description = "Image to deploy — passed in from Jenkinsfile"
  type        = string
  default     = "furkandevops/flask-terraform-pipeline:latest"
}
```
- `variable` — Declares an input parameter (like a function argument)
- `description` — Human-readable docs. Shows up in `terraform plan` output
- `type = string` — Validates that whoever passes this variable gives a string
- `default` — Used if no value is passed. Jenkins will override this with the actual build tag

```hcl
variable "app_port" {
  type    = number
  default = 5000
}
```
- `type = number` — Only accepts numbers, rejects "5000" as a string (type safety)

```hcl
variable "container_name" {
  type    = string
  default = "flask-terraform-app"
}
```
- This name will be used as the Docker container's name (`docker ps` will show this)

### Block 4: Docker Image Resource
```hcl
resource "docker_image" "app" {
  name         = var.docker_image
  keep_locally = false
}
```
- `resource "docker_image" "app"` — Two-part name:
  - `docker_image` = the resource type (from the `kreuzwerker` provider)
  - `app` = your local label (used to reference this resource elsewhere)
- `name = var.docker_image` — Pull this image from Docker Hub. `var.docker_image` reads the variable defined above
- `keep_locally = false` — When you run `terraform destroy`, delete the image from local disk too. `true` would keep it cached

### Block 5: Docker Container Resource
```hcl
resource "docker_container" "app" {
  name  = var.container_name
  image = docker_image.app.image_id
```
- `docker_container` = resource type for running containers
- `"app"` = local label
- `name = var.container_name` → container named `flask-terraform-app`
- `image = docker_image.app.image_id` — Reference the image ID (SHA hash) from the resource above. This creates an implicit dependency — Terraform pulls the image FIRST, then creates the container

```hcl
  restart = "always"
```
- Docker restart policy: `always` = restart if it crashes OR if Docker daemon restarts. Options: `no`, `on-failure`, `unless-stopped`, `always`

```hcl
  ports {
    internal = var.app_port   # Port INSIDE the container (Flask listens here)
    external = var.app_port   # Port on YOUR machine (you browse here)
  }
```
- Maps `localhost:5000` → `container:5000`
- Like `docker run -p 5000:5000`

```hcl
  env = [
    "FLASK_ENV=production"
  ]
```
- Injects environment variables into the container
- Flask uses `FLASK_ENV` to disable debug mode, enable optimizations

```hcl
  must_run = true
```
- Terraform will error if the container stops. Ensures the container stays running after apply

```hcl
  healthcheck {
    test         = ["CMD", "curl", "-f", "http://localhost:5000/health"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 3
    start_period = "15s"
  }
}
```
- `test` — Command Docker runs to check health. `-f` makes `curl` fail on HTTP errors
- `interval` — Check every 30 seconds
- `timeout` — If `curl` takes >10s, mark as failed
- `retries` — After 3 consecutive failures → container marked unhealthy
- `start_period` — Wait 15s after startup before counting failures (app needs time to boot)

### Block 6: Outputs
```hcl
output "app_url" {
  value = "http://localhost:${var.app_port}"
}
output "container_name" {
  value = docker_container.app.name
}
output "image_deployed" {
  value = var.docker_image
}
```
- `Outputs` print to terminal after `terraform apply` completes
- Also queryable with `terraform output app_url`
- `${var.app_port}` = string interpolation (embeds variable value into string)
- `docker_container.app.name` = reads the `.name` attribute from the container resource

## 📄 JENKINSFILE (CI/CD Pipeline)

### Pipeline Structure
```groovy
pipeline {
    agent any
}
```
- `pipeline {}` — Declarative pipeline syntax (modern Jenkins)
- `agent any` — Run on any available Jenkins node/executor. Could be `agent { label 'linux' }` to target specific machines

### Environment Variables
```groovy
environment {
    DOCKER_HUB_REPO  = "furkandevops/flask-terraform-pipeline"
    DOCKER_CRED_ID   = "dockerhub-credentials"
    IMAGE_TAG        = "${env.BUILD_NUMBER}"
}
```
- `environment {}` — Declares variables available to ALL stages
- `DOCKER_HUB_REPO` — The Docker Hub repo path (username/repo-name)
- `DOCKER_CRED_ID` — The ID string of credentials stored in Jenkins Credentials Manager (not the actual password!)
- `IMAGE_TAG = "${env.BUILD_NUMBER}"` — Jenkins auto-increments `BUILD_NUMBER` each run. So build 42 creates tag `:42`. This makes every build traceable and rollbackable

### Stage 1: Checkout
```groovy
stage('Checkout') {
    steps {
        checkout scm
        echo "✅ Code pulled from GitHub"
    }
}
```
- `checkout scm` — `scm` = Source Control Management. Pulls code from whatever repo is configured in the Jenkins job (GitHub, GitLab, etc.)
- Downloads the exact commit that triggered this pipeline run

### Stage 2: Install & Lint
```groovy
stage('Install & Lint') {
    steps {
        sh '''
            python3 -m venv --without-pip venv
'''
```
- `sh '''...'''` — Runs a multi-line shell script on the Jenkins agent
- `python3 -m venv` — Creates an isolated Python environment in a folder called `venv`
- `--without-pip` — Skip installing pip during `venv` creation (workaround for restricted environments)

```groovy
            . venv/bin/activate
            curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
            python get-pip.py --no-warn-script-location
```
- `. venv/bin/activate` — The dot (`.`) = `source`. Activates the virtual environment
- Downloads pip installer script from the official Python authority
- Installs pip manually into the `venv`

```groovy
            pip install --upgrade pip
            pip install -r requirements.txt
            pip install flake8
            flake8 app.py --max-line-length=120 || true
        '''
    }
}
```
- `pip install -r requirements.txt` — Installs all app dependencies listed in that file
- `flake8 app.py` — Linter: checks Python code style and catches errors (unused imports, bad syntax, etc.)
- `--max-line-length=120` — Allow lines up to 120 chars (default is 79)
- `|| true` — Even if `flake8` finds issues, don't fail the pipeline. Remove this in strict projects

### Stage 3: Docker Build & Push
```groovy
stage('Docker Build & Push') {
    steps {
        withCredentials([usernamePassword(
            credentialsId: "${DOCKER_CRED_ID}", 
            passwordVariable: 'DOCKERHUB_PASSWORD', 
            usernameVariable: 'DOCKERHUB_USERNAME')]) {
```
- `withCredentials` — Securely injects credentials. The actual password is never visible in logs (Jenkins masks it)
- `credentialsId` — Looks up stored credentials by the ID we defined in `environment`
- `passwordVariable / usernameVariable` — Names of shell variables Jenkins creates temporarily

```groovy
            sh """
                echo "${DOCKERHUB_PASSWORD}" | docker login -u "${DOCKERHUB_USERNAME}" --password-stdin
```
- `"""` — Double-quote heredoc (allows variable interpolation, unlike `'''`)
- Pipes the password via `stdin` — more secure than `-p password` (which appears in process list)

```groovy
                docker build -t ${DOCKER_HUB_REPO}:${IMAGE_TAG} .
                docker build -t ${DOCKER_HUB_REPO}:latest .
```
- Builds the image twice with different tags:
  - `:42` (specific build number) → for rollbacks, audit trail
  - `:latest` → always points to newest build
- The `.` = build context is the current directory (uses `Dockerfile` in root)

```groovy
                docker push ${DOCKER_HUB_REPO}:${IMAGE_TAG}
                docker push ${DOCKER_HUB_REPO}:latest
            """
        }
    }
}
```
- Uploads both tagged images to Docker Hub so Terraform can pull them

### Stage 4: Terraform Deploy
```groovy
stage('Terraform Deploy') {
    steps {
        dir('terraform') {
```
- `dir('terraform')` — Changes working directory to the `terraform/` folder for all commands inside

```groovy
            sh '''
                docker rm -f flask-terraform-app || true
'''
```
- Force-removes the old container before Terraform runs
- Without this, Terraform may fail trying to create a container with a name that already exists
- `|| true` — If container doesn't exist yet, don't fail

```groovy
                terraform init -input=false
```
- Downloads providers (the Docker plugin), sets up backend
- `-input=false` — Never prompt for input (essential for automation — pipelines can't type answers)

```groovy
                terraform plan -input=false \
                -var="docker_image=${DOCKER_HUB_REPO}:${IMAGE_TAG}" \
                -out=tfplan
```
- `plan` — Calculates what changes Terraform will make (like a dry run)
- `-var="docker_image=..."` — Overrides the default variable with the actual build tag (e.g., `:42`)
- `-out=tfplan` — Saves the plan to a file. This guarantees apply executes exactly what was planned (no drift)

```groovy
                terraform apply -input=false -auto-approve tfplan
            '''
        }
    }
}
```
- `apply` — Executes the saved plan
- `-auto-approve` — Skip the "yes/no" confirmation prompt
- `tfplan` — Use the saved plan file (not a fresh calculation)

### Stage 5: Smoke Test
```groovy
stage('Smoke Test') {
    steps {
        sh '''
            sleep 5
            curl -sf http://localhost:5000/health
            echo ""
            echo "✅ App is live at http://localhost:5000"
        '''
    }
}
```
- `sleep 5` — Wait 5 seconds for the container to fully start
- `curl -sf` — `-s` = silent (no progress bar), `-f` = fail with exit code on HTTP errors (4xx/5xx)
- Hits the `/health` endpoint — if Flask responds with `200 OK`, the stage passes
- If `curl` fails (non-zero exit), Jenkins marks the stage RED and pipeline fails

### Post Actions
```groovy
post {
    success {
        echo "🎉 Pipeline SUCCESS — Build #${env.BUILD_NUMBER} deployed!"
    }
    failure {
        echo "❌ Pipeline FAILED — check the red stage above"
    }
    always {
        sh 'docker image prune -f || true'
        cleanWs()
    }
}
```
- `post {}` — Runs **after all stages**, regardless of outcome
- `success` — Only runs if ALL stages passed
- `failure` — Only runs if any stage failed
- `always` — Runs no matter what (cleanup)
- `docker image prune -f` — Deletes **dangling images** (untagged leftover layers) to free disk space
- `cleanWs()` — Jenkins built-in: deletes the workspace folder to keep the agent clean

---

## 🗺️ How It All Connects
```
GitHub Push
    │
    ▼
Jenkins pulls code (Checkout)
    │
    ▼
Install deps + lint Python (Install & Lint)
    │
    ▼
Build Docker image → Push to Docker Hub (Docker Build & Push)
  :42 + :latest
    │
    ▼
Terraform pulls :42 from Docker Hub
Terraform runs it as a container on port 5000 (Terraform Deploy)
    │
    ▼
curl /health confirms app is live (Smoke Test)
    │
    ▼
Cleanup dangling images + workspace
```
Every build gets a unique tag (`:42`, `:43`...) so you can always roll back by running Terraform with an older tag. Terraform manages the container declaratively — you describe what you want, it figures out how to get there.
