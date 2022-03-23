#! /bin/bash
registry_host="asia.gcr.io"
registry_ns="chamith-testunited/testunited/examples-learnright"
image_prefix="learnright"
chart_dir="learnright"
chart_file="$chart_dir/Chart.yaml"
image_values_file="$chart_dir/values.images.yaml"
manifest_file="learnright.manifest"
app_version=$1
environment=$2
registry_key_file=$3
app_version_match_string="appVersion: \"$app_version\""
app_version_matched=$(grep -c "$app_version_match_string" "$chart_file")

if [ $app_version_matched != 1 ]
then
  echo "App version in Helm Chart does not match with the version mentioned."
  exit 0
fi

if [ ! -n "$environment" ]
then
echo "Target environment is not provided."
  exit 0
else
  env_values_file="$chart_dir/values.$environment.yaml"
  release_name="learnright-$environment"
fi

if [ -n "$registry_key_file" ]
then
  cat $registry_key_file | docker login -u _json_key --password-stdin "https://${registry_host}"
fi

echo "#### Learnright v$app_version #####" > $image_values_file
echo "# Service Images" >> $image_values_file
echo "images:" >> $image_values_file

while read name build_tag sem_ver rc_sequence ; do

  if [ $environment == "prd" ]
  then
    release_tag="$sem_ver"
  else
    release_tag="$sem_ver-$rc_sequence"
  fi

  printf "%s\n" "name: ${name}"
  printf "%s\n" "build_tag: ${build_tag}"
  printf "%s\n" "release_tag: ${release_tag}"
  image_full_name="$registry_host/$registry_ns/$image_prefix-$name"
  docker pull "$image_full_name:${build_tag}"
  docker tag "$image_full_name:${build_tag}" "$image_full_name:${release_tag}"
  docker push "$image_full_name:${release_tag}"
  echo "  $name: $image_full_name:${release_tag}" >> $image_values_file
done < $manifest_file

printf "%s\n" "image_values_file: ${image_values_file}"
printf "%s\n" "env_values_file: ${env_values_file}"
printf "%s\n" "app_version: ${app_version}"
printf "%s\n" "release_name: ${release_name}"
printf "%s\n" "chart_dir: ${chart_dir}"

helm upgrade -i -f $image_values_file -f $env_values_file --description appVersion:$app_version $release_name $chart_dir
# helm upgrade -i -f ./learnright/values.images.yaml -f ./learnright/values.int.yaml learnright-int ./learnright/