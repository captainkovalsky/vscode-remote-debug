imageName="dotnetcoredemo"
projectName="dotnetcoredemo"
serviceName="dotnetcoredemo"
containerName="${projectName}_${serviceName}_1"
runtimeID="debian.8-x64"
framework="netcoreapp1.1"

# Kills all running containers of an image and then removes them.
cleanAll () {
  if [[ -z $ENVIRONMENT ]]; then
    ENVIRONMENT="debug"
  fi

  composeFileName="docker-compose.yml"
  if [[ $ENVIRONMENT != "release" ]]; then
    composeFileName="docker-compose.$ENVIRONMENT.yml"
  fi

  if [[ ! -f $composeFileName ]]; then
    echo "$ENVIRONMENT is not a valid parameter. File '$composeFileName' does not exist."
  else
    docker-compose -f $composeFileName -p $projectName down --rmi all

    # Remove any dangling images (from previous builds)
    danglingImages=$(docker images -q --filter 'dangling=true')
    if [[ ! -z $danglingImages ]]; then
      docker rmi -f $danglingImages
    fi
  fi
}

# Builds the Docker image.
buildImage () {
  if [[ -z $ENVIRONMENT ]]; then
    ENVIRONMENT="debug"
  fi

  composeFileName="docker-compose.yml"
  if [[ $ENVIRONMENT != "release" ]]; then
    composeFileName="docker-compose.$ENVIRONMENT.yml"
  fi

  if [[ ! -f $composeFileName ]]; then
    echo "$ENVIRONMENT is not a valid parameter. File '$composeFileName' does not exist."
  else
    echo "Building the project ($ENVIRONMENT)."
    pubFolder="bin/$ENVIRONMENT/$framework/publish"
    dotnet publish -f $framework -r $runtimeID -c $ENVIRONMENT -o $pubFolder

    echo "Building the image $imageName ($ENVIRONMENT)."
    docker-compose -f "$pubFolder/$composeFileName" -p $projectName build
  fi
}

# Runs docker-compose.
compose () {
  if [[ -z $ENVIRONMENT ]]; then
    ENVIRONMENT="debug"
  fi

  composeFileName="docker-compose.yml"
  if [[ $ENVIRONMENT != "release" ]]; then
      composeFileName="docker-compose.$ENVIRONMENT.yml"
  fi

  if [[ ! -f $composeFileName ]]; then
    echo "$ENVIRONMENT is not a valid parameter. File '$composeFileName' does not exist."
  else
    echo "Running compose file $composeFileName"
    docker-compose -f $composeFileName -p $projectName kill
    docker-compose -f $composeFileName -p $projectName up -d
  fi
}

startDebugging () {
  containerId=$(docker ps -f "name=$containerName" -q -n=1)
  if [[ -z $containerId ]]; then
    echo "Could not find a container named $containerName"
  else
    docker exec -i $containerId /vsdbg/vsdbg --interpreter=vscode
  fi
}

# Shows the usage for the script.
showUsage () {
  echo "Usage: dockerTask.sh [COMMAND]"
  echo "    Runs build or compose using debug environment"
  echo ""
  echo "Commands:"
  echo "    build: Builds a Docker image ('$imageName')."
  echo "    clean: Removes the image '$imageName' and kills all containers based on that image."
  echo "    composeForDebug: Builds the image and runs docker-compose."
  echo "    startDebugging: Finds the running container and starts the debugger inside of it."
  echo ""
  echo "Environments:"
  echo "    debug: Uses debug environment."
  echo ""
  echo "Example:"
  echo "    ./dockerTask.sh build"
  echo ""
  echo "    This will:"
  echo "        Build a Docker image named $imageName using debug environment."
}

if [ $# -eq 0 ]; then
  showUsage
else
  case "$1" in
    "composeForDebug")
            export REMOTE_DEBUGGING=1
            buildImage
            compose
            ;;
    "startDebugging")
            startDebugging
            ;;
    "build")
            buildImage
            ;;
    "clean")
            cleanAll
            ;;
    *)
            showUsage
            ;;
  esac
fi