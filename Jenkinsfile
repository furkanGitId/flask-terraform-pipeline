// pipeline {
//     agent any

//     environment {
//         // ── Change this to YOUR Docker Hub username ──
//         DOCKER_HUB_REPO  = "furkandevops/flask-terraform-pipeline"
//         DOCKER_CRED_ID   = "dockerhub-credentials"   // must match Jenkins credential ID
//         //SONAR_TOKEN_ID   = "sonarqube-token"          // must match Jenkins credential ID
//         IMAGE_TAG        = "${env.BUILD_NUMBER}"      // each build gets a unique number tag
//     }

//     stages {

//         // ── STAGE 1 ──────────────────────────────────────────────────────────
//         // Pull the latest code from GitHub
//         stage('Checkout') {
//             steps {
//                 checkout scm
//                 echo "✅ Code pulled from GitHub"
//             }
//         }

//         // ── STAGE 2 ──────────────────────────────────────────────────────────
//         // Create a Python virtual environment, install packages, run flake8 linter
//         // flake8 checks your code style — catches things like unused imports, long lines
//         stage('Install & Lint') {
//             steps {
//                 sh '''
//                     python3 -m venv venv
//                     . venv/bin/activate
//                     pip install --upgrade pip
//                     pip install -r app/requirements.txt
//                     flake8 app/ --max-line-length=120
//                 '''
//                 echo "✅ Dependencies installed and lint passed"
//             }
//         }

//         // ── STAGE 3 ──────────────────────────────────────────────────────────
//         // Run all pytest tests and generate two reports:
//         //   - JUnit XML  → Jenkins shows pass/fail counts
//         //   - coverage XML → SonarQube shows which lines are tested
//         stage('Test') {
//             steps {
//                 sh '''
//                     . venv/bin/activate
//                     mkdir -p reports
//                     pytest tests/ -v \
//                         --junitxml=reports/test-results.xml \
//                         --cov=app \
//                         --cov-report=xml:reports/coverage.xml
//                 '''
//                 echo "✅ All tests passed"
//             }
//             post {
//                 always {
//                     // Show test results in Jenkins UI even if tests fail
//                     junit 'reports/test-results.xml'
//                 }
//             }
//         }

//         // ── STAGE 4 ──────────────────────────────────────────────────────────
//         // Send your code to SonarQube for analysis
//         // SonarQube checks: bugs, code smells, duplications, test coverage
//         // stage('SonarQube Analysis') {
//         //     steps {
//         //         withSonarQubeEnv('SonarQube') {
//         //             withCredentials([string(credentialsId: "${SONAR_TOKEN_ID}", variable: 'SONAR_TOKEN')]) {
//         //                 sh """
//         //                     sonar-scanner \
//         //                       -Dsonar.projectKey=todo-cicd-pipeline \
//         //                       -Dsonar.projectName=todo-cicd-pipeline \
//         //                       -Dsonar.sources=app \
//         //                       -Dsonar.tests=tests \
//         //                       -Dsonar.python.coverage.reportPaths=reports/coverage.xml \
//         //                       -Dsonar.login=${SONAR_TOKEN}
//         //                 """
//         //             }
//         //         }
//         //         echo "✅ SonarQube analysis complete"
//         //     }
//         // }

//         // ── STAGE 5 ──────────────────────────────────────────────────────────
//         // Wait for SonarQube to finish and give a PASS or FAIL result
//         // If quality gate FAILS → pipeline stops here, nothing gets deployed
//         // timeout = 5 minutes max wait time
//         // stage('Quality Gate') {
//         //     steps {
//         //         timeout(time: 5, unit: 'MINUTES') {
//         //             waitForQualityGate abortPipeline: true
//         //         }
//         //         echo "✅ Quality gate passed"
//         //     }
//         // }

//         // ── STAGE 6 ──────────────────────────────────────────────────────────
//         // Build a Docker image from your Dockerfile
//         // Then push it to Docker Hub with two tags:
//         //   - "42"      (the build number — so you can roll back to any version)
//         //   - "latest"  (always points to the newest build)
//         stage('Docker Build & Push') {
//             steps {
//                 script {
//                     docker.withRegistry('https://registry.hub.docker.com', DOCKER_CRED_ID) {
//                         def img = docker.build("${DOCKER_HUB_REPO}:${IMAGE_TAG}", ".")
//                         img.push()           // push with build number tag
//                         img.push("latest")   // also push as latest
//                     }
//                 }
//                 echo "✅ Docker image pushed to Docker Hub"
//             }
//         }

//         // ── STAGE 7 ──────────────────────────────────────────────────────────
//         // Terraform reads your terraform/main.tf config file and:
//         //   init  → downloads required plugins (only needed first time)
//         //   plan  → shows what it WILL do (like a dry run)
//         //   apply → actually does it — deploys your Docker container
//         stage('Terraform Deploy') {
//             steps {
//                 dir('terraform') {
//                     sh '''
//                         terraform init -input=false
//                         terraform plan -input=false \
//                             -var="docker_image=${DOCKER_HUB_REPO}:${IMAGE_TAG}" \
//                             -out=tfplan
//                         terraform apply -input=false -auto-approve tfplan
//                     '''
//                 }
//                 echo "✅ Terraform deployment complete"
//             }
//         }

//         // ── STAGE 8 ──────────────────────────────────────────────────────────
//         // Hit the /health endpoint to confirm the app actually started
//         // sleep 5 gives the container a moment to fully start up
//         // curl -sf → silent mode, fails if response is not 200 OK
//         stage('Smoke Test') {
//             steps {
//                 sh '''
//                     sleep 5
//                     curl -sf http://localhost:5000/health
//                     echo ""
//                     echo "✅ App is live at http://localhost:5000"
//                 '''
//             }
//         }
//     }

//     // ── POST ACTIONS ──────────────────────────────────────────────────────────
//     // These run AFTER all stages, no matter what happened
//     post {
//         success {
//             echo "🎉 Pipeline SUCCESS — Build #${env.BUILD_NUMBER} is deployed!"
//         }
//         failure {
//             echo "❌ Pipeline FAILED — Check the stage above that went red"
//         }
//         always {
//             // Clean up dangling Docker images to free disk space
//             sh 'docker image prune -f || true'
//             // Delete workspace files to keep Jenkins disk clean
//             cleanWs()
//         }
//     }
// }

pipeline {
    agent any

    environment {
        DOCKER_HUB_REPO  = "furkandevops/flask-terraform-pipeline"
        DOCKER_CRED_ID   = "dockerhub-credentials"
        IMAGE_TAG        = "${env.BUILD_NUMBER}"
    }

    stages {

        // ── STAGE 1 ──────────────────────────────────────────────────────────
        stage('Checkout') {
            steps {
                checkout scm
                echo "✅ Code pulled from GitHub"
            }
        }

        // ── STAGE 2 ──────────────────────────────────────────────────────────
        // requirements.txt is in root folder (not inside app/)
        stage('Install & Lint') {
            steps {
                sh '''
                    sudo apt-get update -y
                    sudo apt-get install -y python3 python3-pip python3-venv  # venv optional but harmless

                    python3 -m pip install --upgrade pip
                    python3 -m pip install -r requirements.txt
                    python3 -m pip install flake8  # ensure flake8 is available

                    flake8 app.py --max-line-length=120
                '''
                echo "✅ Dependencies installed and lint passed"
            }
        }

        // ── STAGE 3 ──────────────────────────────────────────────────────────
        // app.py is in root so pytest looks in root directly
        stage('Test') {
            steps {
                sh '''
                    python3 -m pip install pytest  # if not already in requirements.txt
                    mkdir -p reports
                    python3 -m pytest -v --junitxml=reports/test-results.xml
                '''
                echo "✅ All tests passed"
            }
            post {
                always {
                    junit 'reports/test-results.xml'
                }
            }
        }

        // ── STAGE 4 ──────────────────────────────────────────────────────────
        // Build Docker image and push to Docker Hub
        // furkandevops/flask-terraform-pipeline:1  (build number)
        // furkandevops/flask-terraform-pipeline:latest
        stage('Docker Build & Push') {
            steps {
                sh """
                    echo "\$DOCKERHUB_PASSWORD" | docker login -u "\$DOCKERHUB_USERNAME" --password-stdin
                    docker build -t ${DOCKER_HUB_REPO}:${IMAGE_TAG} .
                    docker push ${DOCKER_HUB_REPO}:${IMAGE_TAG}
                    docker push ${DOCKER_HUB_REPO}:latest
                """
            }
        }

        // ── STAGE 5 ──────────────────────────────────────────────────────────
        // Terraform pulls the image and runs it as a container
        stage('Terraform Deploy') {
            steps {
                dir('terraform') {
                    sh """
                        terraform init -input=false
                        terraform plan -input=false \
                            -var="docker_image=${DOCKER_HUB_REPO}:${IMAGE_TAG}" \
                            -out=tfplan
                        terraform apply -input=false -auto-approve tfplan
                    """
                }
                echo "✅ Terraform deployment complete"
            }
        }

        // ── STAGE 6 ──────────────────────────────────────────────────────────
        // Confirm the container is actually running and responding
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
    }

    post {
        success {
            echo "🎉 Pipeline SUCCESS — Build #${env.BUILD_NUMBER} deployed!"
            echo "🌐 App running at http://localhost:5000"
        }
        failure {
            echo "❌ Pipeline FAILED — check the red stage above"
        }
        always {
            sh 'docker image prune -f || true'
            cleanWs()
        }
    }
}