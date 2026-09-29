# Jenkins + Apache Lab

Homework for the SoftServe DevOps course: a Jenkins pipeline that installs the Apache web server
on two remote VMs (Ubuntu and Rocky Linux), deploys test configuration, generates fake 4xx/5xx
requests and analyzes Apache access logs.

The pipeline (`Jenkinsfile`) is stored in this repository, and Jenkins runs it directly from GitHub
(*Pipeline script from SCM*).

## Task coverage

| Task | Where |
|---|---|
| 1. Install Jenkins and plugins, Jenkinsfile installs httpd/Apache2 on remote VMs | `Jenkinsfile`, `scripts/install_apache.sh`, [Jenkins setup](#jenkins-setup) |
| 2. Read Apache logs, find 4xx/5xx errors, make fake requests | `scripts/fake_requests.sh`, `scripts/check_logs.sh`, `conf/lab-errors.conf` |
| \* Deployment pipeline in GitHub, run in Jenkins from the repository | job `apache-deploy` → Pipeline script from SCM |
| Screenshots / video | [Results](#results) |

## Lab architecture

```
Windows host: VirtualBox + Vagrant only
│
├── DevOps1  (Ubuntu 24.04 Server, VirtualBox VM)
│     192.168.0.32   bridged   -> Jenkins UI: http://192.168.0.32:8090
│     192.168.56.10  host-only -> talks to web VMs
│     Git, Jenkins LTS, Java 21
│
│        ssh (key "web-ssh-key")
│              ▼
├── web1  192.168.56.20  Ubuntu 22.04   -> apache2  (created by Vagrant)
└── web2  192.168.56.21  Rocky Linux 9  -> httpd    (created by Vagrant)
```

Vagrant only creates "empty" servers and adds the Jenkins public SSH key.
**Apache is installed by Jenkins**, not by Vagrant.

## Repository structure

```
Vagrantfile               # web1 (Ubuntu) + web2 (Rocky), host-only network, Jenkins public key
Jenkinsfile               # the pipeline
scripts/
  install_apache.sh       # installs apache2 or httpd (auto-detects OS), idempotent
  deploy_config.sh        # puts lab-errors.conf into Apache, configtest, reload
  fake_requests.sh        # sends requests that return 400/403/404/414/500/503
  check_logs.sh           # counts 4xx/5xx in access log, report by code and URL
conf/
  lab-errors.conf         # test endpoints: /error500, /error503, /private (403)
.gitattributes            # LF line endings for scripts (repo is also used on Windows)
.gitignore                # .vagrant/, reports/, build/, SSH private keys
```

## Pipeline

```
Checkout SCM → Validate scripts → Install Apache → Deploy config → Smoke test
             → Generate fake requests → Analyze logs → post: archive reports
```

| Stage | What it does |
|---|---|
| Validate scripts | `bash -n` syntax check for every script in `scripts/` |
| Install Apache | on each host: `ssh ... 'sudo bash -s' < scripts/install_apache.sh` |
| Deploy config | `scp` of `lab-errors.conf` + `deploy_config.sh` (configtest before reload) |
| Smoke test | `curl` to each host, build fails if a host does not answer (HTTP 000) |
| Generate fake requests | `fake_requests.sh` for each host |
| Analyze logs | `check_logs.sh` on each host, output saved to `reports/apache-<ip>.txt` |
| post | `archiveArtifacts` saves the reports with the build |

All hosts are processed in a loop over `TARGET_HOSTS`, so adding a new server means adding one IP.

### How the fake errors are made

| Code | Request |
|---|---|
| 404 | non-existing pages, `/wp-login.php` (typical bot scan) |
| 400 | HTTP/1.1 request without the `Host` header (`curl -H 'Host:'`) |
| 414 | URL with 9000 characters |
| 403 | `/private/` (`Require all denied` in `lab-errors.conf`) |
| 500 / 503 | `/error500`, `/error503` (`Redirect 500` / `Redirect 503` in `lab-errors.conf`) |

### Example report (build artifact)

```
========== Apache log report: web1 ==========
Log file   : /var/log/apache2/access.log
All lines  : 37
4xx errors : 24
5xx errors : 6

--- Errors by status code ---
     14 404
      4 400
      3 503
      3 500
      3 414
      3 403
```

## How to run

### 1. Web VMs (Windows, PowerShell)

```powershell
vagrant up
vagrant status
```

### 2. Jenkins setup (DevOps1) <a id="jenkins-setup"></a>

```bash
sudo apt install -y fontconfig openjdk-21-jre-headless
sudo wget -O /etc/apt/keyrings/jenkins-keyring.asc https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key
echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" \
  | sudo tee /etc/apt/sources.list.d/jenkins.list
sudo apt update && sudo apt install -y jenkins
```

Java 21 and port 8090 are set with a systemd override (`sudo systemctl edit jenkins`):

```ini
[Service]
Environment="JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64"
Environment="JENKINS_PORT=8090"
```

Plugins: suggested plugins + **SSH Agent** + **Pipeline: Stage View**.

### 3. SSH access Jenkins → web VMs

```bash
ssh-keygen -t ed25519 -f ~/.ssh/jenkins_web -N "" -C "jenkins-lab"   # public key goes to Vagrantfile
sudo -u jenkins mkdir -p /var/lib/jenkins/.ssh
ssh-keyscan -t ed25519 192.168.56.20 192.168.56.21 | sudo -u jenkins tee -a /var/lib/jenkins/.ssh/known_hosts
```

Private key → Jenkins Credentials: kind *SSH Username with private key*, ID `web-ssh-key`, username `vagrant`.

### 4. Job

New Item → Pipeline `apache-deploy` → *Pipeline script from SCM* → Git →
`https://github.com/AndriiVoitovychDevops/jenkins-apache-lab.git`, branch `*/main`, script path `Jenkinsfile` → **Build Now**.

## Problems found and fixed

| Problem | Cause | Fix |
|---|---|---|
| Jenkins did not start: `Failed to start Jetty` | ports 8080–8082 were already used by nginx | `JENKINS_PORT=8090` via systemd override |
| Jenkins needs Java 21, system has 17 | new Jenkins LTS requires Java 21+ | Java 21 installed next to 17, `JAVA_HOME` only for Jenkins |
| `.gitignore` template ignored all project files | GitHub template *Jenkins_Home* is for backing up `/var/lib/jenkins` | own `.gitignore` for this project |
| Port 80 was not opened on Rocky, but the script succeeded | typo `>dev/null` made the `if` always false | removed the redirect, firewall step is outside the install check |
| `$(hostname)` printed DevOps1 instead of web1 | double quotes are expanded locally before ssh | remote command in single quotes, Groovy `'''...'''` |
| Log analysis showed codes `514`, `248` | 414 lines have no `HTTP/1.1`, so `awk '{print $9}'` shifts | parse by quotes: `awk -F'"' '{split($3,a," "); print a[1]}'` |
| `deploy_config.sh`: file "not found" although it existed | `[ ! -f "SRC" ]` without `$` checks a file named `SRC` | `[ ! -f "$SRC" ]` |
| `git push` rejected | a commit was made on GitHub web UI | `git pull --rebase`, then push |

## Results

- Stage View: all stages green
- Console Output of Install Apache and Generate fake requests
- Build Artifacts: `apache-192.168.56.20.txt`, `apache-192.168.56.21.txt`
- `http://192.168.56.20/error500` in a browser
