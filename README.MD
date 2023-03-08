# Ubuntu 22.04 LTS 

## configuration script for Java programming <br><br>

**1. Use wget to download the script**

```bash
wget -O setup.sh https://raw.githubusercontent.com/smaginv/ubuntu/master/setup.sh
```

**2. Make the script executable**
```bash
chmod +x setup.sh
```

**3. Run the script**
```bash
./ setup.sh
```

#

## Features

**1. completely removed snap:**

- firefox
- snap-store
- ...
- snapd

**2. installed programs:**

- GNOME Tweaks
- Extension Manager
- Synaptic
- cURL
- Git (configuring git user during installation)
- OpenJDK (with a choice of versions)
- Apache Maven (with a choice of version)
- Gradle (with a choice of version)
- JetBrains Toolbox App
- Visual Studio Code
- Docker
- Docker Compose
- pgAdmin 4
- Postman
- Google Chrome

**3. Docker images:**

- postgres

**4. GNOME Shell Extensions:**

- Docker
- Clipboard-indicator
- Removable Drive Menu
- Notification Banner Reloaded
