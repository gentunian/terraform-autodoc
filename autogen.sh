#!/usr/bin/env sh

# hacky way to exclude packages, use spaces at start, end and between words
# TODO: improve this :)
EXCLUDE=" scaffolding azure-classic "

# We could use Link header but keep it simple
GITHUB_REPO_URL=https://api.github.com/orgs/terraform-providers/repos?page=\${PAGE}
while true;
do
    PAGE=$((PAGE + 1))
    echo "Getting github repositories from: $(eval echo ${GITHUB_REPO_URL})"
    REPOS=$(eval curl -s ${GITHUB_REPO_URL} | jq -r 'map(.html_url | split("https://")[1]) | join("\n")')
    [ -z "${REPOS}" ] && echo "Repositories found: $(echo ${PROVIDERS} | wc -w)." && break
    PROVIDERS="${PROVIDERS} ${REPOS}"

done

# Process providers
for repo in ${PROVIDERS};
do
    PROVIDER_NAME=${repo/*terraform-provider-/}
    if [ "${EXCLUDE/* ${PROVIDER_NAME} */${PROVIDER_NAME}}" == "${PROVIDER_NAME}" ]; then
        continue
    fi
    cat <<EOF >> autodoc_${PROVIDER_NAME}.go
package main

import (
	"fmt"
	"reflect"
        tfProvider "$repo/$PROVIDER_NAME"
)

func main() {
	provider := tfProvider.Provider()
	providerValue := reflect.ValueOf(provider).Elem()
	providerData := providerValue.FieldByName("Schema")
	resourceData("$PROVIDER_NAME", providerData)
	providerResources("Resources", providerValue)
        providerResources("DataSources", providerValue)
}

func providerResources(resourceType string, provider reflect.Value) {
	resourcesMap := provider.FieldByName(resourceType + "Map")
	resourcesMapKeys := resourcesMap.MapKeys()
	if len(resourcesMapKeys) > 0 {
		fmt.Println("* " + resourceType)
	}
	for i := range resourcesMapKeys {
		item := resourcesMapKeys[i]
		resourceSchema := resourcesMap.MapIndex(item).Elem().FieldByName("Schema")
		resourceData(item.String(), resourceSchema)
	}
}

func resourceData(resourceName string, schema reflect.Value) {
	fmt.Printf("    * %s\n", resourceName)
	schemaKeys := schema.MapKeys()
	for i := range schemaKeys {
		argumentName := schemaKeys[i].String()
		argumentStruct := schema.MapIndex(schemaKeys[i]).Elem()
		argumentDescription := argumentStruct.FieldByName("Description").String()
		argumentDeprecated := argumentStruct.FieldByName("Deprecated").String()
		if argumentDeprecated != "" {
			argumentDeprecated = "[DEPRECATED] " + argumentDeprecated
		}
		argumentRequired := ""
		if argumentStruct.FieldByName("Required").Bool() {
			argumentRequired = "Required"
		} else if argumentStruct.FieldByName("Optional").Bool() {
			argumentRequired = "Optional"
		} else {
			argumentRequired = "Computed"
		}

		fmt.Printf("\t* %-30s: (%s) %s%s\n", argumentName, argumentRequired, argumentDescription, argumentDeprecated)
	}
}
EOF
done

echo "autodoc.go file created..."
