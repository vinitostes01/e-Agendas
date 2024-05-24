library(stringr)
library(httr)
library(dplyr)
url = "https://eagendas.cgu.gov.br"

pagina = httr::GET(url) |> 
  content(as = "text")
orgaos = stringr::str_match(pagina, '<div ng-init="orgaos(.*?)]"')[,1]
orgaos = gsub('<div ng-init="orgaos=' , "", orgaos)
orgaos = gsub('&quot;' , '\"', orgaos)
orgaos = jsonlite::fromJSON(orgaos)

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
  agentes = rbind(agentes, pagina_agentes)
}


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







