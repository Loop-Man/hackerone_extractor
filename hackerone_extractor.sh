#!/bin/bash

# Author: Manuel Lopez Torrecillas aka Loop-Man (https://github.com/Loop-Man)
# Objective: Search all domain in the programs of Hackerone by API.

#Colours
greenColour="\e[0;32m\033[1m"
endColour="\033[0m\e[0m"
redColour="\e[0;31m\033[1m"
blueColour="\e[0;34m\033[1m"
yellowColour="\e[0;33m\033[1m"
purpleColour="\e[0;35m\033[1m"
turquoiseColour="\e[0;36m\033[1m"
grayColour="\e[0;37m\033[1m"

# Source the Global Configuration with variables and API keys
. global.conf

if [ ! "$HACKERONE_USER" ] || [ ! "$HACKERONE_API_KEY" ]; then
	echo -e "\n${redColour}[!] You must enter your user and API \
Key of HACKERONE into the config file called global.conf${endColour}\n"
	exit 1
fi

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT


function ctrl_c(){
    echo -e "\n\n${yellowColour}[*]${endColour}${grayColour} Exiting in a \
controlled way${endColour}\n"
    exit 0
}

base_url="https://api.hackerone.com/v1/hackers/programs"
page_number=1
page_size=100
output_file="programs.json"
output_folder="$(pwd)/programs"

if [ ! -d "$output_folder" ];then
    mkdir "$output_folder"
fi

# Limpiando ficheros relevantes.
echo "" > $output_file
echo "" > "HackerOne_Domains_in_scope.txt"

while : ; do
    response=$(curl -s "$base_url?page%5Bnumber%5D=$page_number&page%5Bsize%5D=$page_size" -X GET -u "$HACKERONE_USER:$HACKERONE_API_KEY" -H 'Accept: application/json')
    echo "Downloading bugbounty programs of hackerone page=$page_number"
    
    # Debug
    #echo "Respuesta de la página $page_number:"
    #echo "$response"
    #echo "-------------------------"

    # Verificar si la respuesta tiene datos vacíos
    if [[ "$response" == *'{"data":[],"links":{}}'* ]]; then
        #echo "No hay más páginas. Salir del bucle."
        break
    fi

    echo "$response" >> programs.json
    # Incrementar el número de página para la próxima iteración
    page_number=$((page_number + 1))
done

jq -s '. | {data: map(.data) | add}' programs.json > programs_unified.json
jq -r '.data[].attributes.handle' programs_unified.json > programs_handle.txt

# Leer cada línea del archivo programs_handle.txt
while IFS= read -r handle; do
    
    # Hacer una solicitud curl usando el handle
    
    response2=$(curl -s "$base_url/$handle" -X GET -u "$HACKERONE_USER:$HACKERONE_API_KEY" -H 'Accept: application/json')
    echo "Downloading information of $handle program"
    echo "$response2" > $output_folder/program_$handle.json
    # Espera un poco antes de la siguiente solicitud para no sobrecargar el servidor o evitar ser bloqueado
    sleep 1
done < programs_handle.txt

# Seleccionamos solo los programas con tipo de asset url y elegibles para bounty
jq -r '.relationships.structured_scopes.data[] | select(.attributes.asset_type == "URL" and .attributes.eligible_for_bounty == true) | .attributes.asset_identifier' $output_folder/program_* | sed 's#^http://##; s#^https://##; s/^\*\.//; s/\/.*$//; s/\.\*$//; s/\.$//; s/,\(.*\)/\n\1/g; s/([^)]*)//g ;s/,\(.*\)/\n\1/g; s/^\.//; s/\*//g; s/-\*//g' | sort | uniq > "HackerOne_Domains_in_scope.txt"