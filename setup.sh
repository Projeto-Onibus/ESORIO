#!/bin/bash
#
# FAS-Bus installation script
# Authors: Fernando Dias and Matheus Felinto
# Description: 
#       This script assist in the installation of the FAS-Bus system by asking
#       values for the necessary global variables. As a results it generates a main.conf
#       and a .env file filled with all the necessary data
#
#
# Usage:
#       ./setup.sh {-h|dev|stable}
# Options:
#       -h: displays a help message
#       dev: installs the development release 
#       stable: installs the stable release
#
# More information at: https://fasbus.gta.ufrj.br

# Stops at any error throughout the script
set -e


echo ""
echo ""
echo "FAS-Bus: Fleet Analysis System for Urban Buses"


# Colors for warnings and errors
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
RESET="\e[0m"

# help()
# Description: displays a help message and then exits
help () {
        echo "usage:$0 {-h|dev|stable}"
        echo "This program aids the installation of the FAS-Bus in a single system environment"
        echo "-h: displays this message"
        echo "dev: installs the development version"
        echo "stable: installs the stable version"
        echo "More instructions follow the program execution. No actions are taken before confirmation. "
        exit
}


# function: set_path $1 $2 $3
# Description: 
#       Helps user choose a path for a given purpose. 
#       Checks to see if given name is valid and prints it to the .env file
#       Selects a default path if not given by user
#       Creates a file with the variable's name and writes its value to it
# arguments:
#       $1 -> name of the directory chosen for user display
#       $2 -> Default name if user dont give
#       $3 -> Path's name at .env file 
#       



ValidatePath () {
        if [[ ! -d $1 ]]; then 
                echo "Directory path does not exist"
        fi
        if [[ $(count $(ls $1)) > 0 ]]; then 
                echo "Directory exists but it's not empty"
        fi
        # Valid path
        echo 0
                

}



# Chooses between the help message or the development (or stable) release install. 
case $1 in
        "-h")
                help
                ;;

        "dev")
                COMPOSE_FILE="build"
                DATABASE_MODULE_SOURCE="./FAS-Bus-Database/"
                PROXY_MODULE_SOURCE="./FAS-Bus-visualization/Site/"
                API_MODULE_SOURCE="./FAS-Bus-visualization/API/"
                INSERTION_MODULE_SOURCE="./FAS-Bus-insertion/"  
                CORRECTION_MODULE_SOURCE="./FAS-Bus-correction/"
                ;;

        "stable")
                
                COMPOSE_FILE="image"
                DATABASE_MODULE_SOURCE="fdms-3741/fas-bus-database"
                PROXY_MODULE_SOURCE="fdms-3741/fas-bus-site"
                API_MODULE_SOURCE="fdms-3741/fas-bus-visualization"
                INSERTION_MODULE_SOURCE="fdms-3741/fas-bus-insertion"  
                CORRECTION_MODULE_SOURCE="fdms-3741/fas-bus-correction"
                ;;

        *)
                help
                ;;        
esac


# ------------------------------------------------------------------------------------------
# Functions for the display of colorful messages
# ------------------------------------------------------------------------------------------
no-skip () {
        if [[ -z $1 ]];then
                echo "\n"
        else
                echo $1
        fi
}
critical () {
        printf "$RED[%s]$RESET%s$(no-skip $2)" "[!!!CRITICAL!!!]" ": $1"
        exit
}

error () {
printf "$RED[%s]$RESET%s$(no-skip $2)" "[ERROR]" ": $1"
}

warning () {
printf "$YELLOW[%s]$RESET%s$(no-skip $2)" "[WARNING]" ": $1"
}


info () {
printf "$YELLOW[%s]$RESET%s$(no-skip $2)" "[INFO]" ": $1"
}


success () {
printf "$GREEN[%s]$RESET%s$(no-skip $2)" "[SUCCESS]" ": $1"
}

# ----------------------------------------------------------------------------------------------

# ----------------------------------------------------------------------------------------------
# Instalation script begin
# ----------------------------------------------------------------------------------------------

info "This script will guide you through the definition of variables required for the system to work."
info "Beggining setup"




# ----------------------------------------------------------------
# Sets database password
# ----------------------------------------------------------------
while true; do 
        echo ""
        echo ""
        echo "-------Set the database password------------"
        warning "This password is nedded in all containers that communicate with the database. Handle this with care."
        info "If you want to generate a secure random password, just leave this blank and say (Y)es to the generated password question"
        printf "Choose a password (max 32 chars):"
        read -s -n 32 FIRST_ATTEMPT    
        echo ""
        if [[ -z $FIRST_ATTEMPT ]]; then
                printf "Are you sure you want a randomly generated password? (Y/n):"
                read -n 1 CHOICE
                echo ""
                case $CHOICE in
                        "Y")
                                FIRST_ATTEMPT=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 31)
                                break
                                ;;
                        *)
                                error "Password not set"
                                continue
                esac
        fi
        printf "Retype a password (max 32 chars):"
        read -s -n 32 SECOND_ATTEMPT
        echo ""

        if [[ $FIRST_ATTEMPT == $SECOND_ATTEMPT ]]; then
                break
        fi
        error "The passwords don't match"
done

success "Database password set"
# ------------------------------------------------------------------------

# ------------------------------------------------------------------------
# Setting the API port
# ------------------------------------------------------------------------

ONLY_DIGITS="^\\d+\$"
while true; do
        printf "API port (default 80): "
        read -n 6 API_PORT
        if [[ -z $API_PORT ]]; then {
                warning "Using default value 80"
                API_PORT=80
                break
        }
        elif [[ ! $API_PORT =~ [0-9]* ]]; then
                error "must be a number"
                continue
        elif [[ $API_PORT < 1024 ]]; then
                warning "Ports less than 1024 require root privileges when docker-compose command runs."
                break
        elif [[ $API_PORT < 65365 ]];then
                break
        else
                error "Invalid port number"
                continue
        fi
        error "invalid port number"
        API_PORT=""
done
# ------------------------------------------------------------------------

# ------------------------------------------------------------------------
# Setting paths
# ------------------------------------------------------------------------

DATABASE_PATH=$(pwd)"/database"

if [[ ! -d $DATABASE_PATH ]]; then
        mkdir $DATABASE_PATH
fi

RAW_DATA_PATH=$(pwd)"/collected"

if [[ ! -d $RAW_DATA_PATH ]]; then
        mkdir $RAW_DATA_PATH
fi


# ------------------------------------------------------------------------

# ------------------------------------------------------------------------
# Creating necessary files 
# ------------------------------------------------------------------------

info "Creating environment file"

if [[ -e .env ]]; then
        warning ".env file exists in this directory. setting a new file and changing current's name to .env.bkp"
        mv .env ".env.$(date +%Y-%m-%d--%H-%M-%S).bkp"
        touch .env
fi

if [[ -e main.conf ]]; then
        warning "main.conf exists. Setting new file and replacing old with backup"
        mv main.conf "main.conf.$(date +%Y-%m-%d--%H-%M-%S).bkp"
fi

# ------------------------------------------------------------------------

# ------------------------------------------------------------------------
# Setting the system's timezone
# ------------------------------------------------------------------------

printf "Set local timezone: "
read LOCAL_TIMEZONE

# ------------------------------------------------------------------------



# ------------------------------------------------------------------------
# Installing necessary repositories for the development install
# ------------------------------------------------------------------------
if [[ $1 == 'dev' ]]; then
        while true; do
                warning "Development releases downlwoad the git repositories to the current directory"
                printf "continue? (Y/n)"
                read DOWNLOAD_REPOS
                case $DOWNLOAD_REPOS in
                        "Y")
                                git clone https://github.com/Projeto-Onibus/FAS-Bus-visualization.git
                                git clone https://github.com/Projeto-Onibus/FAS-Bus-insertion.git
                                git clone https://github.com/Projeto-Onibus/FAS-Bus-Database.git
                                git clone https://github.com/Projeto-Onibus/FAS-Bus-correction.git
                                break
                        ;;
                        "n")
                                error "Cannot proceed with development installation without installing repositories"
                                exit
                        ;;
                        *)
                                error "Could not understand input"
                        ;;
                esac
        done
fi
# ------------------------------------------------------------------------


# ------------------------------------------------------------------------
# Generating configuration files based on templates
# ------------------------------------------------------------------------

cat > .FASBUS.sed.sed << EOF
s;~version~;$COMPOSE_FILE;g
s;\${DATABASE_PASSWORD};$FIRST_ATTEMPT;g
s;\${API_PORT};$API_PORT;g
s;\${LOCAL_TIMEZONE};$LOCAL_TIMEZONE;g
s;\${DATABASE_MODULE_SOURCE};$DATABASE_MODULE_SOURCE;g
s;\${PROXY_MODULE_SOURCE};$PROXY_MODULE_SOURCE;g
s;\${API_MODULE_SOURCE};$API_MODULE_SOURCE;g
s;\${INSERTION_MODULE_SOURCE};$INSERTION_MODULE_SOURCE;g
s;\${CORRECTION_MODULE_SOURCE};$CORRECTION_MODULE_SOURCE;g
s;\${DATABASE_PATH};$DATABASE_PATH;g
s;\${RAW_DATA_PATH};$RAW_DATA_PATH;g
EOF

sed -f .FASBUS.sed.sed .templates/docker-compose-template.yml > docker-compose.yml 

sed "s/###DB_PASSWORD###/password=${FIRST_ATTEMPT}/g" .templates/main.conf.template > main.conf


# -------------------------------------------------------------------------
# Final steps
# -------------------------------------------------------------------------

# Change permissions so it can only be seen by root
info "Setting file permissions"
chmod 600 docker-compose.yml
chmod 600 main.conf
info "Files were set to read/write by root only. In those files the database password is saved. Keep those files secure."

# Removing temporary files
rm .FASBUS.sed.sed


success "The system is ready. Start it as you would do for normal compose daemon deployments: docker-compose up -d"

# done
