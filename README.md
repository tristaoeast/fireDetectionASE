# fireDetectionASE

Para correr o projecto seguir os seguintes passos:

1. Compilar o projecto na sua directoria (a directoria onde está o README.md) com o comando: make micaz sim
2. Correr o script python do simulador com o comando: python app.py
3. Interagir com o servidor através dos comandos apresentados na linha de comandos do mesmo.

Nota: Os eventos de transmissão de mensagens com os valores medidos estão definidos para ocorrer de 1 em 1 minuto, os de detecção de fumo de 15 em 15 segundos e os de detecção de falha de um Routing Node de 5 em 5 minutos. 
Para alterar estes valores, respectivamente, é necessário alterar os campos T_MEASURE, T_SMOKE_MEASURE e T_ALIVE_MEASURE dentro do enumerado no ficheiro Radio.h e compilar o projecto de novo.
