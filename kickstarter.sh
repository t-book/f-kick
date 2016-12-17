#!/bin/bash

############################################
#### Kickstart Script for Fatfree Framework 
#### Needs either composer or git installed 
#### can run with docker
#### toni schönbuchner (2016)
############################################

usage="$(basename "$0") [-h] [-a] [-s] [-c] [-g] [-d] 
--  script for creating directory structure and install of fatfree framework (https://fatfreeframework.com/home)

where:
    -h  show this help text
    -a  define the folder name. default is myapp
    -s 	(docker installation is needed) starts a apache/php7 server. the current folder is linked to the container. you get access over http://localhost 
    -c  add composer packages which will be added automaticully
    -g  force use of github (if you don´t use composer)
    -d  define your own directory structure
    "

################
### GET OPTS ###
################
 
while getopts "a:c:d:hsg" opt; do
  case $opt in
    h) 	echo "$usage"
       	exit 0
       	;;
    a) 	APP_NAME="$OPTARG"
       	;;
    s) 	STARTDOCKER=1
       	;;    
    c) 	composer_packages="$OPTARG"
       	;;
    g) 	USE_GIT=1
		echo "do git"
       	;;          	
    d) 	CUSTOM_STRUCTURE="$OPTARG"
       	;;    
    \?) echo "Invalid option -$OPTARG" >&2
       ;;
  esac
done

#####################
### SET VARIABLES ### 
#####################

USER_PATH=$PWD

if [ -z "$APP_NAME" ]; then
	APP_NAME="myapp"
fi

DIR_STRUCTURE="${APP_NAME}/{app/{model,view,controller},config}"

if [ -n "$CUSTOM_STRUCTURE" ]; then
	APP_NAME=${CUSTOM_STRUCTURE%%/*} 
	DIR_STRUCTURE="$CUSTOM_STRUCTURE"
	echo $APP_NAME
fi


F3GIT="https://github.com/bcosca/fatfree-core.git"

### PREFLIGHT CHECK ### 
type composer >/dev/null 2>&1 || { HASCOMPOSER=0; }
type git >/dev/null 2>&1 || { HASCOMPOSER=0; }
if [ "$HAS_COMPOSER" = 0 ] && [ "$HAS_GIT" = 0 ]; then
	echo "Sorry but I can´t live without git or composer"
	exit 1
fi

#####################################
### CREATE INDEX.PHP FOR GIT VERSION 
#####################################

create_git_index() {
cat <<EOF > index.php
<?php
\$f3=require('$1');

\$f3->route('GET /',
	function(\$f3) {
		echo "coolix";
	}
);

\$f3->run();
EOF
}

#############################################
### CREATE INDEX.PHP FOR COMPOSER VERSION ### 
#############################################

create_composer_index() {
cat <<EOF > index.php
<?php
require_once('$1');
\$f3 = \\Base::instance();

\$f3->route('GET /',
	function(\$f3) {
		echo "cooliy.";
	}
);

\$f3->run();
EOF
}

#######################
### CREATE HTACCESS ### 
#######################

create_htaccess() {
cat <<EOF > htaccess.txt
# Enable rewrite engine and route requests to framework
RewriteEngine On

# Some servers require you to specify the RewriteBase directive
# In such cases, it should be the path (relative to the document root)
# containing this .htaccess file
#
# RewriteBase /

RewriteRule ^(tmp)\/|\.ini$ - [R=404]

RewriteCond %{REQUEST_FILENAME} !-l
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule .* index.php [L,QSA]
RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization},L]
EOF
}

##############################
### CREATES DIRECTORY TREE ### 
##############################

function create_dir {
	if [ "$USE_GIT" = 1 ] 
	then
		eval "mkdir -p $DIR_STRUCTURE"
		cd "$APP_NAME"
		create_git_index 'lib/base.php' 
		create_htaccess
		mkdir "lib"
		cd "lib"
		git clone $F3GIT .
		cd ..
	else
		eval "mkdir -p $DIR_STRUCTURE"
	  	cd $APP_NAME
	  	create_composer_index 'vendor/autoload.php'
	  	create_htaccess
	  	composer require bcosca/fatfree $composer_packages	
	fi
    }

#############
### START ### 
#############

create_dir

#####################################
### START A WEBSERVER FOR TESTING ### 
#####################################

if [ "$STARTDOCKER" = 1 ]; then
	docker run -d -p 80:80 --name fatfreesrv -v "$PWD":/var/www/html  -e PHP_ERROR_REPORTING='E_ALL & ~E_STRICT' php:7.0-apache
fi
