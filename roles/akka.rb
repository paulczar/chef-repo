name "akka"
description "akka role installs and configures akka app on nginx"
run_list "recipe[megam_akka]"

override_attributes(
  :authorization => {
    :sudo => {
      :users => ["ubuntu", "sandbox"],
      :passwordless => true
    }
  }
)
