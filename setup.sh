#!/bin/bash

home_directory="/home/$USER"
tmp_directory="$home_directory/tmp"
tmp_created=false

setup_start_time=$(date +"%T")
start_time_ms=$(date +%s)
os=$(lsb_release -d | sed 's/Description:[[:space:]]*//g')
initial_number_packages=$(dpkg --get-selections | wc --lines)

packages_to_remove=(
    "snap"
    )

packages_to_install=(
    "gnome-tweaks" "gnome-shell-extension-manager" "synaptic"
    "curl" "Git" "SDKMAN!" "OpenJDK" "Maven" "Gradle" "JetBrains Toolbox" "VSCode" "Docker" "pgAdmin 4" 
    "MySQL APT Repository" "Postman" "Google Chrome" "zsh"
    )

docker_images=(
    "postgres" "mysql"
    )

gnome_extensions=(
    "docker@stickman_0x00.com"
    "clipboard-indicator@tudmotu.com" 
    "openweather-extension@jenslody.de"
    "drive-menu@gnome-shell-extensions.gcampax.github.com" 
    "notification-banner-reloaded@marcinjakubowski.github.com"
    )

favorite_apps=(
    "org.gnome.Nautilus.desktop" "org.gnome.Terminal.desktop" "org.gnome.Calculator.desktop"
    "org.gnome.gedit.desktop" "google-chrome.desktop" "code.desktop" "jetbrains-idea.desktop" 
    "postman.desktop" "gnome-system-monitor.desktop" "gnome-control-center.desktop"
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
        removed_packages+=("$1")
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
    installed_packages+=("$1")
}

function installing_sdkman {
    curl -s "https://get.sdkman.io" | bash
    sdkman_is_installed=true
    installed_packages+=("$1")
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
        skipped_packages+=("$1")
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
        installed_packages+=("$1")
    else
        show_warning_message "canceling installation $1"
        skipped_packages+=("$1")
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
        installed_packages+=("$1")
    else
        show_warning_message "canceling installation $1"
        skipped_packages+=("$1")
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
    installed_packages+=("$1")
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
    installed_packages+=("$1")
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
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo usermod -aG docker $USER

    for image in "${docker_images[@]}"
    do
        read -p " pulling a Docker image: $image? [y*/n] (enter = y*) " input
        if [[ "$input" == "y" || "$input" == "" ]]
        then
            sudo docker pull "$image"
            pulling_docker_images+=("$image")
        else
            show_warning_message "skip Docker image: $image"
        fi
    done
    installed_packages+=("$1")
}

function installing_pgadmin {
    curl -fsS https://www.pgadmin.org/static/packages_pgadmin_org.pub | sudo gpg --dearmor -o /usr/share/keyrings/packages-pgadmin-org.gpg
    sudo sh -c 'echo "deb [signed-by=/usr/share/keyrings/packages-pgadmin-org.gpg] https://ftp.postgresql.org/pub/pgadmin/pgadmin4/apt/$(lsb_release -cs) pgadmin4 main" > /etc/apt/sources.list.d/pgadmin4.list'
    sudo apt-get update
    sudo apt-get -y install pgadmin4
    installed_packages+=("$1")
}

function installing_mysql_repository {
    grep_html=$(curl --silent https://dev.mysql.com/downloads/repo/apt/ | grep "mysql-apt-config_*")
    version=${grep_html#*file=}
    mysql_apt_config=${version%&*}
    wget -P "$tmp_directory" "https://repo.mysql.com//$mysql_apt_config"
    sudo apt-get install $tmp_directory/$mysql_apt_config
    sudo apt-get update
    rm $tmp_directory/$mysql_apt_config
    installed_packages+=("$1")

    read -p " would you like to install MySQL Workbench? [y*/n] (enter = y*) " input
    if [[ "$input" == "y" || "$input" == "" ]]
    then
        sudo apt-get -y install mysql-workbench-community
        installed_packages+=("MySQL Workbench")
    else
        skipped_packages+=("MySQL Workbench")
        show_warning_message "skipping MySQL Workbench installation"
    fi
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
    installed_packages+=("$1")
}

function installing_chrome {
    wget -P "$tmp_directory" "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
    sudo apt-get install $tmp_directory/google-chrome-stable_current_amd64.deb
    rm $tmp_directory/google-chrome-stable_current_amd64.deb
    installed_packages+=("$1")
}

function installing_zsh {
    sudo apt-get -y install zsh

    read -p " would you like to install Oh My Zsh? [y*/n] (enter = y*) " input
    if [[ "$input" == "y" || "$input" == "" ]]
    then
        gnome-terminal -- sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
        read -p $'\e[33m press ENTER to continue \e[39m'
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
        git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

        search="plugins=.*"
        replace="plugins=(git zsh-syntax-highlighting zsh-autosuggestions sudo history extract)"

        sed -i "s/$search/$replace/" $home_directory/.zshrc

        echo "
        # Removing all duplicates in .zsh_history
        # setopt HIST_IGNORE_ALL_DUPS

        # Set Git language to English
        #alias git='LANG=en_US git'
        alias git='LANG=en_GB git'" | sed -e 's/^[[:space:]]*//' >> $home_directory/.zshrc

        echo "
            if [ -d /etc/profile.d ]; then
                for i in /etc/profile.d/*.sh; do
                    if [ -r \$i ]; then
                        . \$i
                    fi
                done
                unset i
            fi" | sudo tee -a /etc/zsh/zprofile
    else
        show_warning_message "skipping Oh My Zsh installation"
    fi
    installed_packages+=("$1")
}

function check_sdkman {
    if [[ $sdkman_is_installed == true ]]
    then
        show_info_message "SDKMAN! installed, $1 skipped"
        skipped_packages+=("$1")
    else
        installing_"${1,,}" "$1"
    fi
}

function installing_package {
    read -p " would you like to install $1? [y*/n] (enter = y*) " input
    if [[ "$input" == "y" || "$input" == "" ]]
    then
        case $1 in
            "Git" )
                installing_git "$1"
                ;;
            "SDKMAN!" )
                installing_sdkman "$1"
                ;;
            "OpenJDK" )
                check_sdkman "$1"
                ;;
            "Maven" )
                check_sdkman "$1"
                ;;
            "Gradle" )
                check_sdkman "$1"
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
            "MySQL APT Repository" )
                installing_mysql_repository "$1"
                ;;
            "Postman" )
                installing_postman "$1"
                ;;
            "Google Chrome" )
                installing_chrome "$1"
                ;;
            "zsh" )
                installing_zsh "$1"
                ;;
            * )
                sudo apt-get -y install "${1,,}"
                ;;
        esac
    else
        show_warning_message "skipping $1 installation"
        skipped_packages+=("$1")
    fi
}

for package in "${packages_to_install[@]}"
do
    installing_package "$package"
done

read -p " would you like to install Gnome shell extensions? [y*/n] (enter = y*) " input
if [[ "$input" == "y" || "$input" == "" ]]
then
    gnome_version=$(gnome-shell --version | sed 's/[A-Za-z][[:space:]]*//g' | sed 's/\.[0-9]//g')
    url="https://extensions.gnome.org/download-extension"

    for extension in "${gnome_extensions[@]}"
    do
        extensions+=( "TRUE" "${extension%@*}" )
    done

    installable_extensions=$(zenity --list \
                        --checklist \
                        --separator='\n' \
                        --title="select extensions" \
                        --width=550 \
                        --height=300 \
                        --hide-header \
                        --column="choice" \
                        --column="title" \
                        "${extensions[@]}"
                    )

    for uuid_extension in "${gnome_extensions[@]}"
    do
        for extension in ${installable_extensions[@]}
        do
            if [[ "${uuid_extension}" == "${extension}"* ]]
            then
                uuid="${uuid_extension}"
                wget -O "$tmp_directory/$uuid.zip" "$url/$uuid.shell-extension.zip?shell_version=$gnome_version"
                gnome-extensions install "$tmp_directory/$uuid.zip"
                rm "$tmp_directory/$uuid.zip"
                installed_gnome_extensions+=("$extension")
            fi
        done
    done
else
    show_warning_message "skipping Gnome shell extensions installation"
fi

read -p " would you like to customize your favorite apps? [y*/n] (enter = y*) " input
if [[ "$input" == "y" || "$input" == "" ]]
then
    dock=""
    for app in "${favorite_apps[@]}"
    do
        if [[ $(ls /usr/share/applications | grep "$app") || $(ls $home_directory/.local/share/applications | grep "$app") ]]
        then
            if [[ $dock == "" ]]
            then
                dock="'$app'"
            else
                dock="$dock, '$app'"
            fi
        fi
    done
    gsettings set org.gnome.shell favorite-apps "[$dock]"
    sleep 1
fi

if [[ $tmp_created == true && ! $(ls $tmp_directory) ]]
then
    rm -r $tmp_directory
fi

end_time_ms=$(date +%s)
time_diff=$((end_time_ms - start_time_ms))
minutes=$((time_diff / 60))
seconds=$((time_diff % 60))
setup_end_time=$(date +"%T")

echo "$(
    echo "-------------------------------------------------------"
    echo
    echo " $os setup started: $setup_start_time"
    echo
    echo " $os setup is complete: $setup_end_time"
    echo
    echo " total setup time: $minutes min. $seconds sec."
    echo
    echo " initial number of installed packages: $initial_number_packages"
    echo
    echo " number of packages after installation and configuration: $(dpkg --get-selections | wc --lines)"
    echo
    echo "-------------------------------------------------------"
    echo
)" | tee log

function print_log_array {
    local msg1="$1"
    local msg2="$2"
    shift 2
    local array=("$@")
    echo "$(
        echo
        echo " $msg1 ${#array[@]}"
        echo
        echo " $msg2 "
        echo
        for item in "${array[@]}"
        do
            printf " %s\n" "${item}"
        done
        echo
        echo "-------------------------------------------------------"
        echo
    )" | tee -a log
}

if [[ ${#installed_packages[@]} != 0 ]]
then
    print_log_array "number of installed programs:" "list of installed programs:" "${installed_packages[@]}"
fi

if [[ ${#pulling_docker_images[@]} != 0 ]]
then
    print_log_array "number of pulling Docker images:" "list of pulling Docker images:" "${pulling_docker_images[@]}"
fi

if [[ ${#installed_gnome_extensions[@]} != 0 ]]
then
    print_log_array "number of installed Gnome shell extensions:" "list of installed Gnome shell extensions:" "${installed_gnome_extensions[@]}"
fi

if [[ ${#removed_packages[@]} != 0 ]]
then
    print_log_array "number of deleted programs:" "list of deleted programs:" "${removed_packages[@]}"
fi

if [[ ${#skipped_packages[@]} != 0 ]]
then
    print_log_array "number of skipped programs:" "list of skipped programs:" "${skipped_packages[@]}"
fi

echo
show_info_message " please reboot your system "