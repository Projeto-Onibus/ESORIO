#!/bin/bash
echo "FAS-Bus: Fleet Analysis System for Urban Buses"
echo "This script will guide you through the definition of variables required for the system to work."
echo "Beggining setup"
set -e

# Colors for warnings and errors
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
RESET="\e[0m"

help () {
        echo "usage:$0 {-h|dev|stable}"
        echo "This program aids the installation of the FAS-Bus in a single system environment"
        echo "-h: displays this message"
        echo "dev: installs the development version"
        echo "stable: installs the stable version"
        echo "More instructions follow the program execution. No actions are taken before confirmation. "
        exit
}

# First response to arguments
case $1 in
        "-h")
                help
                ;;

        "dev")
                COMPOSE_FILE="development-release.yml"
                ;;

        "stable")
                COMPOSE_FILE="stable-release.yml"
                ;;

        *)
                help
                ;;        
esac



#
# Functions for the display of colorful messages
# 
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


success "success"
error "error" " "
info "info" "potato\n"
exit
if [[ "$EUID" -ne 0 ]]; then
  critical "Container administration often requires root user privileges. Run this script as root so proper permissions may be set to files."
  exit
fi


while true; do 
        echo ""
        echo ""
        echo "-------Set the database password------------"
        warning "This password is nedded in all containers that communicate with the database. Handle this with care."
        
        printf "Choose a password (max 32 chars):"
        read -s -n 32 FIRST_ATTEMPT    
        echo ""
        if [[ -z $FIRST_ATTEMPT ]]; then
                warning "Are you sure you want a randomly generated password? (Y/n):"
                read -n 1 CHOICE
                echo ""
                case $CHOICE in
                        "Y")
                                FIRST_ATTEMPT=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 13)
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

ONLY_DIGITS="^\\d+\$"
while true; do
        printf "API port (default 80): "
        read -n 6 API_PORT
        if [[ -z $API_PORT ]]; then {
                warning "Using default value 80"
                API_PORT=80
                break
        }
        elif [[ ! $API_PORT =~ ^[0-9]+$ ]]; then
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


info "Creating environment file"

if [[ -e .env ]]; then
        warning ".env file exists in this directory. setting a new file and changing current's name to .env.bkp"
        mv .env ".env.$(date +%Y-%m-%d--%H-%M-%S).bkp"
        touch .env
fi

# Altering database password
echo "DATABASE_PASSWORD=$FIRST_ATTEMPT" >> .env
echo "password=$FIRST_ATTEMPT" >> main.conf
info "set the default port for API interaction."

# Altering
echo "API_PORT=$API_PORT" >> .env

#
# Final steps
#
success "Setup complete"

# Change permissions so it can only be seen by root
info "Setting file permissions"
chmod 600 .env
chmod 600 main.conf
info "Files were set to read/write by root only. In those files is saved the database password. Keep those files secure."

# Changing the desired version name to the main compose file
info "Changing the $1 file ($COMPOSE_FILE) name to docker_compose.yml"
cp $COMPOSE_FILE docker_compose.yml
info "The system is ready. Start it as you would do for normal compose daemon deployments: docker-compose up -d"
