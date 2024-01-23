#!/bin/bash

# Prompt the user for the path to the Terraform file
read -p "Enter the path to your Terraform file: " TERRAFORM_FILE

# Check if the Terraform file exists
if [ ! -f "$TERRAFORM_FILE" ]; then
    echo "Error: Terraform file '$TERRAFORM_FILE' not found."
    exit 1
fi

# Specify the path for the generated Terratest file
TERRATEST_FILE="./test_module_test.go"

# Initialize an array to store output variable names
output_variables=()

# Flag to check if at least one output block is found
output_found=false

# Read the file line by line
while IFS= read -r line; do
  # Check if the line contains the "output" keyword
  if [[ $line =~ ^output[[:space:]]+\"([^\"]+)\" ]]; then
    # Extract the variable name from the matched regex
    output_var="${BASH_REMATCH[1]}"
    
    # Add the variable name to the array
    output_variables+=("$output_var")
    
    # Set the flag to true since at least one output block is found
    output_found=true
  fi
done < "$TERRAFORM_FILE"

# Check if at least one output block is found
if [ "$output_found" = false ]; then
    echo "Error: No output blocks found in Terraform file '$TERRAFORM_FILE'."
    exit 1
fi

# Generate the Terratest file content
TERRATEST_CONTENT=$(cat <<EOF
package test

import (
	"os"
	"testing"
	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestTerraformModule(t *testing.T) {
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "path/to/your/terraform/code",
		Lock: true,
		BackendConfig: map[string]interface{}{
			"bucket":         "terraform-module-state-files",
			"key":            os.Getenv("terraformS3Key"),
			"region":         "us-east-1",
			"dynamodb_table": "terraform-module-state-files",
		},
	})

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	//accountId := aws.GetAccountId(t)
	//region := terraformOptions.BackendConfig["region"].(string)
	
	\n
EOF
)

# Add assertions for each output variable
for variable in "${output_variables[@]}"; do
  TERRATEST_CONTENT+="\t$variable := terraform.Output(t, terraformOptions, \"$variable\")\n"
  TERRATEST_CONTENT+="\tassert.Equal(t, $variable, \"\")\n\n"
done

# Close the TestTerraformModule function
TERRATEST_CONTENT+="}\n"

# Write the content to the Terratest file
echo -e "$TERRATEST_CONTENT" > "$TERRATEST_FILE"

echo "Terratest file created: $TERRATEST_FILE"

