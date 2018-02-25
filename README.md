# Kafka Deployment

This is the project that contains the scripts, configuration, and dockerfiles for building the Docker images of Kafka and some of the Connect API services that connect to it.

## Prerequisites

### Offline
* Docker
* Docker Compose
* Maven 3.1+

## Installing dependencies
* Clone the git repository
* Go to the project directory and perform ‘mvn clean package’

## Using Docker to build the images and run the application
* Make sure Docker and Docker Compose are available on your machine
* Run ‘docker-compose build’
* Run ‘docker-compose up -d’
