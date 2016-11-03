target = "test_lambda.zip"
source = "test_lambda"

desc "Where the lambda function code lives"
directory source

desc "The zip file that terraform exepcts"
file target => source do |t, args|
  sh "cd #{source} && zip -r #{target} . && mv *.zip ../"
end

desc "Make the zip, run apply, and send SNS message to test things"
task :run do |t, args|
  sh <<EOF
#!/bin/bash -x
rm *.zip
rake #{target}
terraform apply
aws sns publish --topic-arn "$(terraform output topic_arn)" \
  --subject "test" --message "test"
EOF
end
