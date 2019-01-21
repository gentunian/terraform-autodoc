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
        "strconv"
        "strings"
        tfProvider "$repo/$PROVIDER_NAME"
)

func main() {
        provider := tfProvider.Provider()
        providerValue := reflect.ValueOf(provider).Elem()
        providerData := providerValue.FieldByName("Schema")
        providerJSON := resourceData("openstack", providerData)
        resourcesJSON := providerResources("Resources", providerValue)
        datasourcesJSON := providerResources("DataSources", providerValue)
        fmt.Printf("{ \"resources\": %s, \"datasources\": %s, \"provider\": %s }", resourcesJSON, datasourcesJSON, providerJSON)
}

func providerResources(resourceType string, value reflect.Value) string {
        resourcesMap := value.FieldByName(resourceType + "Map")
        resourcesMapKeys := resourcesMap.MapKeys()
        var a []string
        for i := range resourcesMapKeys {
                item := resourcesMapKeys[i]
                resourceSchema := resourcesMap.MapIndex(item).Elem().FieldByName("Schema")
                json := resourceData(item.String(), resourceSchema)
                a = append(a, json)
        }
        return fmt.Sprintf("[%s]", strings.Join(a, ","))
}

func resourceData(resourceName string, schema reflect.Value) string {
        schemaKeys := schema.MapKeys()
        var a []string
        for i := range schemaKeys {
                argumentName := schemaKeys[i].String()
                argumentStruct := schema.MapIndex(schemaKeys[i]).Elem()
                argumentDescription, _ := strconv.Unquote(strings.Replace(argumentStruct.FieldByName("Description").String(), "\n", "", 10))
                argumentDeprecated, _ := strconv.Unquote(strings.Replace(argumentStruct.FieldByName("Deprecated").String(), "\n", "", 10))
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
                json := fmt.Sprintf("{\"name\": \"%s\", \"description\": \"(%s) %s%s\"}", argumentName, argumentRequired, argumentDescription, argumentDeprecated)
                a = append(a, json)
        }

        values := strings.SplitN(resourceName, "_", 2)
        resourceURL := "https://www.terraform.io/docs/providers/%s/"
        if len(values) == 1 {
                resourceURL = fmt.Sprintf(resourceURL+"index.html", values[0])
        } else {
                resourceURL = fmt.Sprintf(resourceURL+"r/%s.html", values[0], values[1])
        }

        return fmt.Sprintf("{\"name\": \"%s\", \"url\": \"%s\", \"arguments\": [%s]}", resourceName, resourceURL, strings.Join(a, ","))
}
EOF
done

echo "autodoc.go file created..."
