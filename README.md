# Raspagem do e-Agendas em R

A raspagem de dados (ou web scraping) é uma técnica amplamente utilizada para extrair informações de websites de forma automatizada. No contexto do e-Agendas, uma plataforma que organiza e disponibiliza informações sobre compromissos e agendas públicas de diversos órgãos governamentais, a raspagem de dados pode ser uma ferramenta extremamente útil.

Para a raspagem pelo R usaremos o pacote httr. Primeiramente vamos ler a página cuja URL é "https://eagendas.cgu.gov.br".

```{r}
library(httr)

url = "https://eagendas.cgu.gov.br"

# httr
pagina = httr::GET(url) |> 
  content(as = "text")
```
Esse trecho de código faz uma requisição GET para a URL especificada e transforma o conteúdo da página em uma string completa. Fazemos isso porque os dados que queremos extrair estão contidos no HTML dessa página.

Com a página carregada e convertida em uma string, utilizamos a função str_match do pacote stringr para extrair as informações de todos os órgãos presentes na página.
```{r}
library(stringr)
orgaos = stringr::str_match(pagina, '<div ng-init="orgaos(.*?)]"')[,1]
```
Todos os órgãos etão contidos no HTML no trecho que começa com "<div ng-init="orgaos" e termina com " ]" ", após pegar a string contida nesse intervalo nós tiramos o termo "<div ng-init="orgaos=" para que ela fique no formato JSON.
```
orgaos = gsub('<div ng-init="orgaos=' , "", orgaos)
```
Agora para que fique no formato certo do JSON basta substituir os termos "\&quot;" por " " ", e por fim usar a função fromJSONdo pacote jsonlitepara transformar os dados em um dataframe.
```{r}
orgaos = gsub('&quot;' , '\"', orgaos)

orgaos = jsonlite::fromJSON(orgaos)
```
Precisamos desse conjunto de dados para pegar o ID de cada orgão, esse ID é necessário para acessar a agenda de cada participante dos orgão.

Agora iremos pegar os dados de cada agente de cada orgão, essas informações estão em uma URL em que é necessário apenas o código do orgão, com um looping for vamos pegar as informações de todos os agentes.
```{r}
library(dplyr)

# Criamos um data.frame vazio para juntar todos os agentes
agentes = data.frame()
for (i in 1:nrow(orgaos)) {
  # Pegamos o ID do orgao para colocar na url
  id_orgao = orgaos$id[i]
  # Aqui juntamos o ID do orgao na url 
  url_agentes = paste0("https://eagendas.cgu.gov.br/pesquisa/agentes-publicos-obrigados-por-orgao/orgao/", 
      id_orgao,"/ativo/true")
  # Lemos a URL e transformamos o JSON em um data.frame
  pagina_agentes = httr::GET(url_agentes) |> 
      content(as = "text", encoding = "UTF-8")
  pagina_agentes = jsonlite::fromJSON(pagina_agentes)
  # Por fim juntamos todos os agentes em um data.frame
  agentes = dplyr::bind_rows(agentes, pagina_agentes)
}
```
O data.frame agentes vai conter a informação de todos os agentes que existem no e-Agentes, alguns órgão não utilizam o e-Agendas e por isso não constará nenhum agente.

Por fim basta capturarmos a agenda de cada agente, usando um looping for vamos passar pot todos os agentes para capturar toda a agenda existente de cada agente.
```{r}
# Criamos um data.frame vazio para juntar todos os agentes
agendas = data.frame()
for (i in 1:nrow(agentes)) {
  # Pegamos as informações de Id do orgão, do servidor para colocar na URL
  id_orgao = agentes$orgao_id[i]
  id_servidor = agentes$pertenencia_id[i]
  # Pegamos o cargo e utilizamos o URLencode para codificar a string 
  cargo = URLencode(agentes$cargo[i], reserved = TRUE)
  # Concatenamos na url
  url_ageda = paste0("https://eagendas.cgu.gov.br/?_token=c5DQBbvEr2IYjPuR8yOD07lhHa4laS3jI5oo54JT&filtro_orgaos_ativos=on&filtro_orgao=",
                     id_orgao,"&filtro_cargos_ativos=on&filtro_cargo=",
                     cargo,"&filtro_apos_ativos=on&filtro_servidor=",
                     id_servidor,"&cargo_confianca_id=&is_cargo_vago=false#divcalendar")
  # Lemos a URL
  pagina_agenda = httr::GET(url_ageda) |> 
    content(as = "text", encoding = "UTF-8")
  # Um if para detectar se o agente tem algum registro no e-Agendas
  if (stringr::str_detect(pagina_agenda, '<div ng-init="events=')) {
    # Pegamos as informações sobre os eventos
    agenda_filtrada = stringr::str_match(pagina_agenda, '<div ng-init="events(.*?)]"')[,1]
    agenda_filtrada = gsub('<div ng-init="events=' , "", agenda_filtrada)
    agenda_filtrada = gsub('&quot;' , '\"', agenda_filtrada)
    # Transformamos os valores em um data.frame
    agenda_filtrada = jsonlite::fromJSON(agenda_filtrada)
    # Juntamos as agenas para um conjunto inteiro
    agendas = dplyr::bind_rows(agendas, agenda_filtrada) 
  }
}
```
No código do looping for, foram feitas algumas ações para garantir a correta codificação das URLs e a coleta de dados dos órgãos de maneira robusta. Primeiramente, utilizamos a função URLencode para codificar o cargo do agente no formato de URL, garantindo que todos os caracteres especiais sejam tratados corretamente. Após isso, seguimos os mesmos passos para a coleta dos dados dos órgãos. Para lidar com agentes que não possuem registros no e-Agendas, adicionamos uma estrutura if para verificar a presença de dados antes de tentar processá-los. No final, utilizamos a função bind_rows para combinar as agendas em um único data frame, lidando com a possibilidade de tamanhos diferentes devido à variação no número de registros.

O código final pode levar alguns minutos para concluir todas as requisições, mas ao término, teremos um data.frame similar a este:

![image](https://github.com/vinitostes01/e-Agendas/assets/89874338/f7bebe98-68e9-44a1-b6cd-694803f5f6ac)

No final teremos 3 data.frames com dados consolidados, um com todos os orgãos e suas informaçãoes, um de todos os agentes que estão cadastrados no e-Agendas e um com todas os registros de agendas no site do e-Agendas. O código completo está disponível no meu [GitHub](https://github.com/vinitostes01/e-Agendas/blob/245c2c9a81737c7af7ed6e81962a4026198169d4/Coleta_e_Agendas.R). Um exemplo de cada uma das bases de dados também está disponível lá.
