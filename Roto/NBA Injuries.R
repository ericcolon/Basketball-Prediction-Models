#http://www.rotoworld.com/teams/injuries/nba/all

library(dplyr)
library(magrittr)
library(jsonlite)
library(tidyr)
library(purrr)
library(stringr)
library(rvest)
library(httr)
library(lubridate)
library(tidyr)
library(nbastatR)

options(warn = -1)
get_player_names <- function(){
  data <- 
    data_frame(
      name.player = c("J.J. Barea", "Amare Stoudemire", "C.J. Watson", "Nene Hilario"),
      name.nba = c("Jose Juan Barea", "Amar'e Stoudemire", "CJ Watson", "Nene")
      
    )
  return(data)
}


get_nba_player_injuries <- function(filter_returning_today = T){
  url <-
    "http://www.rotoworld.com/teams/injuries/nba/all"
  
  page <-
    url %>%
    read_html()
  
  players <-
    page %>%
    html_nodes("td:nth-child(1) a") %>%
    html_text()
  
  injury <-
    page %>%
    html_nodes("td:nth-child(2) span") %>%
    html_text()
  
  injury.timeline <-
    page %>%
    html_nodes("td:nth-child(2) .impact") %>%
    html_text() %>%
    str_to_lower %>%
    str_trim()
  
  date.information <-
    page %>%
    html_nodes("td:nth-child(2) .date") %>%
    html_text() %>%
    paste0(", ",
           Sys.Date() %>% year()
           ) %>%
    mdy() %>%
    as.Date()
  
  date.injury <-
    page %>%
    html_nodes("tr+ tr td:nth-child(5)") %>%
    html_text() %>%
    paste0(", ",
           Sys.Date() %>% year()
    ) %>%
    mdy() %>%
    as.Date()
  
  injury.detail <-
    page %>%
    html_nodes(".report") %>%
    html_text
  
  injury_data <-
    data_frame(date.information,
               name.player = players,
               date.injury,
               injury,
               injury.timeline,
               injury.detail)
  
  player_ids <-
    nbastatR::get_nba_players_ids()
  player_missing_df <-
    get_player_names()
  injury_data %<>%
    left_join(player_missing_df) %>%
    mutate(name.player = ifelse(name.nba %>% is.na, name.player, name.nba)) %>%
    dplyr::select(-name.nba) %>%
    left_join(
      player_ids %>%
        dplyr::select(name.player,team)
    ) %>%
    filter(!is.na(team)) %>%
    select(team, name.player, everything()) %>%
    arrange(team)
  
  injury_data %<>%
    mutate(is.gtd = ifelse(injury.timeline == "day-to-day", T, F)) %>%
    dplyr::select(team, name.player, is.gtd, everything())
  
  injury_data %<>%
    separate(injury.timeline, into= c("remove", "date.return"), sep="target",
             remove = F) %>%
    select(-remove) %>%
    mutate(date.return = date.return %>% gsub("\\ing", "",.),
           date.return = date.return %>% gsub("\\.", "", .) %>% str_trim(),
           date.return = ifelse(!date.return %>% is.na & date.return %>% nchar < 7,
                                yes = date.return %>%
                                  paste0(", ",
                                         Sys.Date() %>% year()
                                  ) %>%
                                  mdy() %>%
                                  as.Date() %>% as.character, date.return)
           )
  if (filter_returning_today == T){
    active_players <-
      injury_data %>%
      filter(date.return == Sys.Date() %>% as.character() |
                     date.return == Sys.Date() %>% weekdays() %>% str_to_lower
                   ) %>%
      .$name.player
    
  injury_data %<>%
    filter(!name.player %in% active_players)
  }
  
  return(injury_data)
}


