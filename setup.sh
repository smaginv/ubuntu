#!/bin/bash

home_directory="/home/$USER"
tmp_directory="$home_directory/tmp"
tmp_created=false

packages_to_remove=(
    "snap"
    )

packages_to_install=(
    "gnome-tweaks" "gnome-shell-extension-manager" "synaptic"
    "curl" "Git" "Open JDK" "Maven" "Gradle" "JetBrains Toolbox" "VSCode" "Docker" "pgAdmin 4" "Postman" 
    "Google Chrome"
    )

function show_warning_message {
    echo -e "\e[31m $1 \e[39m"
}

function show_info_message {
    echo -e "\e[33m $1 \e[39m"
}

function removing_snap {
    sudo systemctl disable snapd.service
    sudo systemctl disable snapd.socket
    sudo systemctl disable snapd.seeded.service
    sudo snap remove firefox
    sudo snap remove snap-store
    sudo snap remove gtk-common-themes
    sudo snap remove bare
    sudo snap remove gnome-3-38-2004
    sudo snap remove snapd-desktop-integration
    sudo snap remove core20

    sudo apt-get -y purge snapd
    sudo apt-get -y autoremove
    rm -rf $home_directory/snap
    sudo rm -rf /snap /root/snap /run/snapd
}

function removing_package {
    read -p " would you like to remove $1? [y*/n] (enter = y*) " input
    if [[ "$input" == "y" || "$input" == "" ]]
    then
        all_removed_packages+=("$1")
        case $1 in
            "snap" )
                removing_snap
                ;;
            * )
                sudo apt-get -y purge $1
                sudo apt-get -y autoremove
                ;;
        esac
    else
        show_warning_message "skipping $1 deletion"
    fi
}

for package in "${packages_to_remove[@]}"
do
    removing_package "$package"
done

if [[ ! -d $tmp_directory ]]
then
    mkdir $tmp_directory
    tmp_created=true
fi

function check_or_installing_package {
    package=$(dpkg -l | grep "$1")
    if [[ ! $package ]]
    then
        sudo apt-get -y install $1
    fi
}

function installing_git {
    sudo apt-get -y install git

    show_info_message " configure Git "

    read -p " enter your Git user.name: " input
    git config --global user.name "$input"
    
    read -p " enter your Git user.email: " input
    git config --global user.email "$input"
    
    git config --global core.autocrlf input
    git config --global core.safecrlf warn
    git config --global core.quotepath off
}

function installing_openjdk {
    all_packages=($(apt-cache search openjdk-..-jdk))

    for package in "${all_packages[@]}"
    do
        if [[ ! "${package%openjdk-**-jdk}" ]]
        then
            version=$(echo $package | sed 's/-jdk//g')
            if [[ ! -d /usr/lib/jvm ]]
            then
                possible_versions+=( "TRUE" "$version-jdk" )
            elif [[ ! $(ls /usr/lib/jvm/ | grep "$version") ]]
            then
                possible_versions+=( "TRUE" "$version-jdk" )
            fi
        fi
    done

    versions=$(zenity --list \
                --checklist \
                --separator='\n' \
                --title="installing $1" \
                --width=550 \
                --height=300 \
                --hide-header \
                --column="choice" \
                --column="version $1" \
                "${possible_versions[@]}"
            )

    if [[ $versions ]]
    then
        for version in ${versions[@]}
        do
            sudo apt-get -y install $version
            installed_packages+=("$version")
        done

        sudo update-alternatives --config java

        all_installed=($(ls /usr/lib/jvm/ | grep "java-..-"))
        installed=()
        for package in "${all_installed[@]}"
        do
            installed+=( "" "$package" )
        done
        jdk_home=$(zenity --list \
                        --radiolist \
                        --title="choice JAVA_HOME" \
                        --width=550 \
                        --height=300 \
                        --hide-header \
                        --column="choice" \
                        --column="version $1" \
                        "${installed[@]}"
                    )

        if [[ $jdk_home ]]
        then
            echo "JAVA_HOME=\"/usr/lib/jvm/$jdk_home\"" | sudo tee -a /etc/environment
            is_installed_jdk=true
        fi
    else
        show_warning_message "canceling installation $1"
    fi
}

function show_all_available_versions {
    all_available_versions=($1)
    all_versions=()

    for version in "${all_available_versions[@]}"
    do
        all_versions+=( "" "$version" )
    done

    installable_version=$(zenity --list \
                    --radiolist \
                    --title="installation $2" \
                    --width=550 \
                    --height=300 \
                    --hide-header \
                    --column="choice" \
                    --column="version $2" \
                    "${all_versions[@]}"
                )
}

function installing_maven {
    show_all_available_versions "$(curl --silent https://dlcdn.apache.org/maven/maven-3/ | grep "[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*" \
                                | sed 's/.*<a href="//g' | sed 's/\/">.*//g')" "$1"

    if [[ $installable_version ]]
    then
        maven="apache-maven-$installable_version-bin.tar.gz"
        wget -O "$tmp_directory/$maven" "https://dlcdn.apache.org/maven/maven-3/$installable_version/binaries/$maven"
        tar -xf "$tmp_directory/$maven" -C "$tmp_directory"
        mv "$tmp_directory/apache-maven-$installable_version" "$tmp_directory/maven"
        sudo cp -r "$tmp_directory/maven" /opt/
        rm -r "$tmp_directory/maven"
        rm "$tmp_directory/$maven"

        echo "export M2_HOME=/opt/maven
            export MAVEN_HOME=/opt/maven
            export PATH=\${M2_HOME}/bin:\${PATH}" | sed -e 's/^[[:space:]]*//' | sudo tee /etc/profile.d/maven.sh
    else
        show_warning_message "canceling installation $1"
    fi
}

function installing_gradle {
    show_all_available_versions "$(curl --silent https://gradle.org/releases/ | grep "<a name=" | sed 's/[A-Za-z_:",/<>= ]//g')" "$1"

    if [[ $installable_version ]]
    then
        gradle="gradle-$installable_version-bin.zip"
        wget -O "$tmp_directory/$gradle" "https://services.gradle.org/distributions/$gradle"
        unzip -q -d "$tmp_directory" "$tmp_directory/$gradle"
        mv "$tmp_directory/gradle-$installable_version" "$tmp_directory/gradle"
        sudo cp -r "$tmp_directory/gradle" /opt/
        rm -r "$tmp_directory/gradle"
        rm "$tmp_directory/$gradle"

        echo "export GRADLE_HOME=/opt/gradle
            export PATH=\${GRADLE_HOME}/bin:\${PATH}" | sed -e 's/^[[:space:]]*//' | sudo tee /etc/profile.d/gradle.sh
    else
        show_warning_message "canceling installation $1"
    fi
}

function check_jdk {
    if [[ $is_installed_jdk || $(dpkg -l | grep "jdk") || $(ls /usr/lib/jvm/) ]]
    then
        installing_"${1,,}" "$1"
    else
        show_warning_message "JDK is not installed, skipping $1 installation"
    fi      
}

function installing_toolbox {
    sudo apt-get -y install libfuse2
    wget -O "$tmp_directory/jetbrains-toolbox.tar.gz" "https://data.services.jetbrains.com/products/download?platform=linux&code=TBA"
    tar -xf $tmp_directory/jetbrains-toolbox.tar.gz -C $tmp_directory/
    rm $tmp_directory/jetbrains-toolbox.tar.gz
    toolbox=$(ls $tmp_directory/ | grep "jetbrains-toolbox")
    $tmp_directory/$toolbox/jetbrains-toolbox            
    
    read -p $'\e[33m wait for JetBrains Toolbox to start and press ENTER to continue \e[39m'
    
    rm -r $tmp_directory/$toolbox
}

function installing_vscode {
    check_or_installing_package "wget"
    check_or_installing_package "gpg"
    check_or_installing_package "apt-transport-https"
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
    sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
    sudo sh -c 'echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
    rm -f packages.microsoft.gpg
    
    sudo apt-get update
    sudo apt-get -y install code
}

function installing_docker {
    check_or_installing_package "ca-certificates"
    check_or_installing_package "curl"
    check_or_installing_package "gnupg"
    check_or_installing_package "lsb-release"

    if [[ ! -d /etc/apt/keyrings ]]
    then
        sudo mkdir -p /etc/apt/keyrings
    fi

    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin
    sudo usermod -aG docker $USER

    compose_version=$(curl --silent https://api.github.com/repos/docker/compose/releases/latest | grep "tag_name" | sed 's/[A-Za-z_:", ]//g')
    sudo wget -O "/usr/local/bin/docker-compose" "https://github.com/docker/compose/releases/download/v$compose_version/docker-compose-$(uname -s)-$(uname -m)"
    sudo chmod +x /usr/local/bin/docker-compose
}

function installing_pgadmin {
    curl -fsS https://www.pgadmin.org/static/packages_pgadmin_org.pub | sudo gpg --dearmor -o /usr/share/keyrings/packages-pgadmin-org.gpg
    sudo sh -c 'echo "deb [signed-by=/usr/share/keyrings/packages-pgadmin-org.gpg] https://ftp.postgresql.org/pub/pgadmin/pgadmin4/apt/$(lsb_release -cs) pgadmin4 main" > /etc/apt/sources.list.d/pgadmin4.list'
    sudo apt-get update
    sudo apt-get -y install pgadmin4
}

function installing_postman {
    wget -O "$tmp_directory/postman.tar.gz" "https://dl.pstmn.io/download/latest/linux64"
    tar -xf $tmp_directory/postman.tar.gz -C $tmp_directory/
    mv $tmp_directory/Postman $tmp_directory/postman
    sudo cp -r $tmp_directory/postman /opt/
    rm -r $tmp_directory/postman
    rm $tmp_directory/postman.tar.gz

    sudo ln -s /opt/postman/Postman /usr/local/bin/postman

    echo "[Desktop Entry]
    Type=Application
    Name=Postman
    Icon=/opt/postman/app/resources/app/assets/icon.png
    Exec=\"/opt/postman/Postman\"
    Comment=Postman GUI
    Categories=Development;Code;" | sed -e 's/^[[:space:]]*//' | sudo tee /usr/share/applications/postman.desktop
}

function installing_chrome {
    wget -P "$tmp_directory" "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
    sudo apt-get install $tmp_directory/google-chrome-stable_current_amd64.deb
    rm $tmp_directory/google-chrome-stable_current_amd64.deb
}

function installing_package {
    read -p " would you like to install $1? [y*/n] (enter = y*) " input
    if [[ "$input" == "y" || "$input" == "" ]]
    then
        case $1 in
            "Git" )
                installing_git "$1"
                ;;
            "Open JDK" )
                installing_openjdk "$1"
                ;;
            "Maven" )
                check_jdk "$1"
                ;;
            "Gradle" )
                check_jdk "$1"
                ;;
            "JetBrains Toolbox" )
                installing_toolbox "$1"
                ;;
            "VSCode" )
                installing_vscode "$1"
                ;;
            "Docker" )
                installing_docker "$1"
                ;;
            "pgAdmin 4" )
                installing_pgadmin "$1"
                ;;
            "Postman" )
                installing_postman "$1"
                ;;
            "Google Chrome" )
                installing_chrome "$1"
                ;;
            * )
                sudo apt-get -y install "${1,,}"
                ;;
        esac
    else
        show_warning_message "skipping $1 installation"
    fi
}

for package in "${packages_to_install[@]}"
do
    installing_package "$package"
done