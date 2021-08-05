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

# Colors for warnings and errors
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
RESET="\e[0m"


# ---------------------------------------------------------------------
# User interaction functions
# ---------------------------------------------------------------------

# help()
# Description: displays a help message and then exits
help () {
        echo "usage:$0 [options] {dev|latest|stable|quick}"
	echo ""
        echo "This program aids the installation of the FAS-Bus in a single system environment"
	echo ""
	echo "Options:"
        printf "\t-h: displays this message\n"
	printf "\t-v: displays info messages\n"
	echo
	echo "Instalation type:"
        printf "\tdev: installs the development version, with local dir clonning necessary repositories\n"
	printf "\tlatest: install the latest version, building directly from the git repositories\n"
        printf "\tstable: installs the stable version, pulling images from the docker hub\n"
	printf "\tquick: Same as stable, but set all variables to default values and executes script automaticaly"
	echo ""
        echo "More instructions follow the program execution. No actions are taken before confirmation. "
	exit
}

ask_proceed_instalation () {
	
	while true; do
		printf "Are you sure you want to proceed? [Y/n]:"
		read -n 2 CHOICE
		case $CHOICE in
			"Y")
				break
				;;
			"n")
				exit 0
				;;
			*)
				error "Invalid input."
		esac
	done
}

random_password (){
	echo $(tr -dc A-Za-z0-9 </dev/urandom | head -c 31) 
}

# ------------------------------------------------------------------------------------------
# Functions for the display of colorful messages
#
# Description: adds a tag for each displayed message
# Usage: <function> <print-program and args>
# Examples: 
#	info printf "message"     	# Prints [INFO]: message; whitout skipping lines
# 	error echo "an error occured"	# Prints [ERROR]: an error occured
# ------------------------------------------------------------------------------------------

critical () {
        printf "$RED[!!CRITICAL!!]$RESET :"
	$@
}

error () {
	printf "$RED[ERROR]$RESET: "
	$@
}

warning () {
	printf "$YELLOW[WARNING]$RESET: "
	$@
}

info () {
	if [[ $VERBOSE ]]; then
		printf "$BLUE[INFO]$RESET: "
		$@
	fi
}

success () {
	if [[ $VERBOSE ]]; then
		printf "$GREEN[SUCCESS]$RESET: " 
		$@
	fi
}

# ----------------------------------------------------------------------------------------------

# ----------------------------------------------------------------------------------------------
# Instalation script begin
# ----------------------------------------------------------------------------------------------

# Default configurations value
DEFAULT_PASSWORD=$(random_password)
DEFAULT_API_PORT=80
DEFAULT_DATABASE_PATH=$(pwd)"/database"
DEFAULT_DATA_COLLECTED_PATH=$(pwd)"/collected"
DEFAULT_LOCAL_TIMEZONE="America/Sao_Paulo"

# Main title
info echo ""
info echo ""
info echo $GREEN"FAS-Bus: Fleet Analysis System for Urban Buses"$RESET
info echo ""
info echo ""

# Chooses between the help message or the development (or stable) release install. 
DEFAULT_VALUES=""
VERBOSE=""
for $ARG in $@; do
	case $ARG in
		"-h")
			help
			;;
		"-v")
			VERBOSE="Yes"
			;;
			
		"dev")
			COMPOSE_FILE="build"
			DATABASE_MODULE_SOURCE="./FAS-Bus-Database/"
			PROXY_MODULE_SOURCE="./FAS-Bus-visualization/Site/"
			API_MODULE_SOURCE="./FAS-Bus-visualization/API/"
			INSERTION_MODULE_SOURCE="./FAS-Bus-insertion/"  
			CORRECTION_MODULE_SOURCE="./FAS-Bus-correction/"
			break
			;;
		"quick")
			DEFAULT_VALUES="yes"
		"latest")
			COMPOSE_FILE="image"
			DATABASE_MODULE_SOURCE="fdms-3741/fas-bus-database"
			PROXY_MODULE_SOURCE="fdms-3741/fas-bus-site"
			API_MODULE_SOURCE="fdms-3741/fas-bus-visualization"
			INSERTION_MODULE_SOURCE="https://github.com/"  	
		"stable")
			COMPOSE_FILE="image"
			DATABASE_MODULE_SOURCE="fdms-3741/fas-bus-database"
			PROXY_MODULE_SOURCE="fdms-3741/fas-bus-site"
			API_MODULE_SOURCE="fdms-3741/fas-bus-visualization"
			INSERTION_MODULE_SOURCE="fdms-3741/fas-bus-insertion"  
			CORRECTION_MODULE_SOURCE="fdms-3741/fas-bus-correction"
			break
			;;
			
		*)
			critical echo "Could not unserstand option $ARG"
			help
			;;        
	esac
done

info echo "This script will guide you through the definition of variables required for the system to work."
info echo "Beggining setup"

if [[ $EUID != 0 ]]; then
	warning echo "Not running as root, permissions may not be set accordinly"
	ask_proceed_instalation
fi

# ----------------------------------------------------------------
# Sets database password
# ----------------------------------------------------------------
if [[ $DEFAULT_VALUES ]]; then
	FIRST_ATTEMPT=$(random_password)
else
while true; do 
        echo ""
        echo ""
        echo "-------Set the database password------------"
        warning echo "This password is nedded in all containers that communicate with the database. Handle this with care."
        info echo "If you want to generate a secure random password, just leave this blank and say (Y)es to the generated password question"
        printf "Choose a password (max 32 chars):"
        read -s -n 32 FIRST_ATTEMPT    
        echo ""
        if [[ -z $FIRST_ATTEMPT ]]; then
                printf "Are you sure you want a randomly generated password? (Y/n):"
                read -n 1 CHOICE
                echo ""
                case $CHOICE in
                        "Y")
                                FIRST_ATTEMPT=$(random_password)
                                break
                                ;;
                        *)
                                error echo "Password not set"
                                continue
                esac
        fi
        printf "Retype a password (max 32 chars):"
        read -s -n 32 SECOND_ATTEMPT
        echo ""

        if [[ $FIRST_ATTEMPT == $SECOND_ATTEMPT ]]; then
                break
        fi
        error echo "The passwords don't match"
	ask_proceed_instalation
done
fi
success echo "Database password set"
# ------------------------------------------------------------------------

# ------------------------------------------------------------------------
# Setting the API port
# ------------------------------------------------------------------------

ONLY_DIGITS="^\\d+\$"

if [[ $DEFAULT_VALUES ]]; then
	API_PORT=$DEFAULT_API_PORT
else
while true; do
        printf "API port (default 80): "
        read -n 6 API_PORT
        if [[ -z $API_PORT ]]; then {
                warning echo "Using default value 80"
                API_PORT=80
                break
        }
        elif [[ ! $API_PORT =~ [0-9]* ]]; then
                error echo "must be a number"
                continue
        elif [[ $API_PORT < 1024 ]]; then
                warning echo "Ports less than 1024 require root privileges when docker-compose command runs."
                break
        elif [[ $API_PORT < 65365 ]];then
                break
        else
                error echo "Invalid port number"
                continue
        fi
        error echo "invalid port number"
        API_PORT=""
done
fi
# ------------------------------------------------------------------------

# ------------------------------------------------------------------------
# Setting paths; TODO: Function to validade directories given by user 
# ------------------------------------------------------------------------

DATABASE_PATH=$DEFAULT_DATABASE_PATH

if [[ ! -d $DATABASE_PATH ]]; then
        mkdir $DATABASE_PATH
fi

RAW_DATA_PATH=$DEFAULT_COLLECTED_DATA_PATH

if [[ ! -d $RAW_DATA_PATH ]]; then
        mkdir $RAW_DATA_PATH
fi


# ------------------------------------------------------------------------

# ------------------------------------------------------------------------
# Creating necessary files 
# ------------------------------------------------------------------------

info echo "Creating environment file"

if [[ -e .env ]]; then
        error echo ".env file exists in this directory."
	if [[ $DEFAULT_VALUES ]]; then 
		exit 1
	fi
	warning echo "Proceeding with installation will append to current filename the current date and '.bkp'"
	ask_proceed_instalation
        mv .env ".env.$(date +%Y-%m-%d--%H-%M).bkp"
        touch .env
fi

if [[ -e main.conf ]]; then
        warning "main.conf exists in this directory."
	if [[ $DEFAULT_VALUES ]]; then 
		exit 1
	fi
	warning echo "Proceeding with installation will append to current filename the current date and '.bkp'"
        ask_proceed_instalation
	mv main.conf "main.conf.$(date +%Y-%m-%d--%H-%M).bkp"
fi

# ------------------------------------------------------------------------

# ------------------------------------------------------------------------
# Setting the system's timezone
# ------------------------------------------------------------------------

info echo "Setting local timezone"
if [[ $DEFAULT_VALUES ]]; then
	LOCAL_TIMEZONE=$DEFAULT_LOCAL_TIMEZONE
else
	printf "Set local timezone: "
	read LOCAL_TIMEZONE
fi
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
                                git clone git@github.com:Projeto-Onibus/FAS-Bus-visualization.git ||  git clone https://github.com/Projeto-Onibus/FAS-Bus-visualization.git
                                git clone git@github.com:Projeto-Onibus/FAS-Bus-insertion.git ||  git clone https://github.com/Projeto-Onibus/FAS-Bus-insertion.git
                                git clone git@github.com:Projeto-Onibus/FAS-Bus-Database.git ||  git clone https://github.com/Projeto-Onibus/FAS-Bus-Database.git
                                git clone git@github.com:Projeto-Onibus/FAS-Bus-correction.git ||  git clone https://github.com/Projeto-Onibus/FAS-Bus-correction.git
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
