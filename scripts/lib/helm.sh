#!/usr/bin/env bash

add_helm_repo() {
   if ! should_execute add_helm_repo; then
     return 1
   fi

   # add the helm repository containing charts for starting AWS service controllers
   if ! helm repo add "$HELM_LOCAL_REPO_NAME" "$HELM_REPO_SOURCE" > /dev/null 2>&1; then
     echo "Unable to add local helm repo from '$HELM_REPO_SOURCE'"
     TEST_PASS=1
     return 1
   fi

  #list the charts in the the local repo
  echo "Validating the presence of '$HELM_REPO_CHART_NAME' in local repo '$HELM_LOCAL_REPO_NAME' "
  helm_repo_output_lines=$(helm search repo "$HELM_LOCAL_REPO_NAME" | grep "$HELM_REPO_CHART_NAME" | wc -l)
  if [[ "$helm_repo_output_lines" -gt 0 ]]; then
    echo "'$HELM_REPO_CHART_NAME' chart is present in local helm repo '$HELM_LOCAL_REPO_NAME'"
  else
    echo "'$HELM_REPO_CHART_NAME' chart is NOT present in local helm repo '$HELM_LOCAL_REPO_NAME'."
    TEST_PASS=1
  fi
}

uninstall_helm_chart() {
  #uninstall the helm chart
 if ! helm uninstall "$HELM_LOCAL_CHART_NAME" > /dev/null 2>&1 ; then
    echo "Failed to uninstall helm chart '$HELM_LOCAL_CHART_NAME'"
    # No need to mark the test as failed if controllers cannot be uninstalled due to some reason.
  fi
}

ensure_controller_pods() {
  if ! should_execute ensure_controller_pods; then
     return 1
  fi

  echo "Checking status of controller pods"
  local all_aws_controller_pods=$($KUBECTL_PATH get pods | grep $HELM_CONTROLLER_NAME_PREFIX | sed 's/^/pods\//' |cut -d" " -f1 | tr '\n' ' ');
  if $KUBECTL_PATH wait --for=condition=Ready $(echo $all_aws_controller_pods) --timeout=300s; then
    echo "Controller pods have successfully started."
  else
    echo "Failed to start controller pods. Exiting... "
    TEST_PASS=1
  fi
}

ensure_helm_chart_installed() {
  if ! should_execute ensure_helm_chart_installed; then
     return 1
  fi

  local __service_name="$1"
  local __ack_service_image_tag="$2" #consist of ack-service_name-commit_sha
  echo "Installing helm chart '$HELM_LOCAL_CHART_NAME' with image $IMAGE_NAME:$__ack_service_image_tag"

  #install/upgrade the helm chart
  #The image name used will be "$AWS_ECR_REGISTRY"/"$AWS_ECR_REPO_NAME":<awsServiceName>-"$__image_tag_suffix"
  if ! helm upgrade --force --install "$HELM_LOCAL_CHART_NAME" "$HELM_LOCAL_REPO_NAME"/"$HELM_REPO_CHART_NAME" --set ackServiceControllerImage="$IMAGE_NAME:$__ack_service_image_tag",ackServiceAlias="$__service_name"> /dev/null 2>&1; then
    echo "Failed to install helm chart '$HELM_LOCAL_CHART_NAME' to test image."
    TEST_PASS=1
  fi
}
