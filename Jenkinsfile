pipeline {
    agent any

    options {
        timestamps()
        timeout(time: 30, unit: 'MINUTES')
    }

    environment {
        SSH_USER     = 'vagrant'
        TARGET_HOSTS = '192.168.56.20 192.168.56.21'   // хости через пробіл
        SSH_CRED     = 'web-ssh-key'
    }

    stages {
        stage('Validate scripts') {
            steps {
		sh 'for f in scripts/*.sh; do bash -n "$f" && echo "OK: $f"; done'
            }
        }

        stage('Install Apache') {
            steps {
                sshagent(credentials: [env.SSH_CRED]) {
                    sh '''
                         for host in $TARGET_HOSTS; do
			      echo "=== Installing apache on $host ==="
			      ssh $SSH_USER@$host 'sudo bash -s' < scripts/install_apache.sh
			done
                    '''
                }
            }
        }

	stage('Deploy config') {
            steps {
                sshagent(credentials: [env.SSH_CRED]) {
                    sh '''
                         for host in $TARGET_HOSTS; do
                              echo "=== Deploying config on $host ==="
				scp conf/lab-errors.conf $SSH_USER@$host:/tmp/
                              ssh $SSH_USER@$host 'sudo bash -s' < scripts/deploy_config.sh
                        done
                    '''
                }
            }
        }


        stage('Smoke test') {
            steps {
                sh '''
			for host in $TARGET_HOSTS; do
                              echo "=== $host ==="
                              code=$(curl -s -o /dev/null -w '%{http_code}' http://$host)
				echo "$host -> HTTP $code"
				if [ "$code" = "000" ]; then
					echo "$host not responding"
					exit 1; 
				fi				
                        done    
                '''
            }
        }
	
	 stage('Generate fake requests') {
            steps {
                sh '''
                        for host in $TARGET_HOSTS; do
				bash scripts/fake_requests.sh $host
                        done
                '''
            }
        }
	
	 stage('Analyze logs') {
            steps {
		sshagent(credentials: [env.SSH_CRED]) {
                    sh '''
                        mkdir -p reports
                        for host in $TARGET_HOSTS; do
                            ssh $SSH_USER@$host 'sudo bash -s' < scripts/check_logs.sh > reports/apache-$host.txt
                            cat reports/apache-$host.txt
                        done
                    '''
                }
            }
        }

    }	

    post {
	always {
            archiveArtifacts artifacts: 'reports/*.txt', allowEmptyArchive: true
        }
	success { echo 'Apache installed and responding on all hosts' }
	failure { echo 'Pipeline failed - check the stage marked red' }
    }
}
