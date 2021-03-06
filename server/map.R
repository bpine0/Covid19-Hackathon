###Load in, filter data###
hospital_data <- reactive({
  
  #####LOAD IN DATABASE HERE INSTEAD OF READ EXCEL, ASSIGN IT TO Hospital_List#####
  #Data from https://hifld-geoplatform.opendata.arcgis.com/datasets/hospitals/data?geometry=94.054%2C-16.829%2C-124.970%2C72.120&selectedAttribute=BEDS
  login <- readLines("login.txt")
  loginTxt <- unlist(strsplit(login, split = "\\t"))
  hdb = dbConnect(MySQL(), 
                  user=loginTxt[1], 
                  password = loginTxt[2], 
                  dbname="hospital_db", 
                  host="hospitaldb2.cbchdqimrdp1.us-east-2.rds.amazonaws.com")
  hosp_info <- dbSendQuery(hdb, "select * from Hospitals_April")
  Hospital_List <-fetch(hosp_info, n=-1)
  
  #Filter for open and > 0 BEDS
  Hospital_List <- Hospital_List %>% filter(STATUS == "OPEN", BEDS > 0,
                                              TYPE == "GENERAL ACUTE CARE" |
                                              TYPE == "CHILDREN")
  
  #Assign colors for markers
  for(row in 1:nrow(Hospital_List)){
    if(Hospital_List[row, "capacity"] == "max capacity"){
      Hospital_List[row, "marker"] = "red"
    }
    else if (Hospital_List[row, "capacity"] == "nearing capacity"){
      Hospital_List[row, "marker"] = "orange"
    }
    else{
      Hospital_List[row,"marker"] = "green"
    }
  }
  
  #Check for input of filters on available capacity
  if(1 %in% input$capacity == FALSE){
    Hospital_List <- Hospital_List %>% filter(capacity != "max capacity")
  }
  
  if(2 %in% input$capacity == FALSE){
    Hospital_List <- Hospital_List %>% filter(capacity != "nearing capacity")
  }
  
  if(3 %in% input$capacity == FALSE){
    Hospital_List <- Hospital_List %>% filter(capacity != "open resources")
  }
  
  #Assign icon for children's hospital vs general
  for(row in 1:nrow(Hospital_List)){
    if(Hospital_List[row,"TYPE"] == "CHILDREN"){
      Hospital_List[row,"icon"] = "child"
    }
    else{
      Hospital_List[row,"icon"] = "h-square"
    }
  }
  
  #Return dataset to be used by leaflet and dt
  Hospital_List
})

###Make map###
output$myMap <- renderLeaflet({
  
  Hospitals <- hospital_data()
  
  #make icons
  icons <- awesomeIcons(
    icon = Hospitals$icon,
    iconColor = 'black',
    library = 'fa',
    markerColor = Hospitals$marker
  )
  
  #create leaflet map
  Hospitals %>% leaflet() %>%
    addTiles() %>%
    addAwesomeMarkers(lat = ~LATITUDE, lng = ~LONGITUDE,  label = ~NAME, icon = icons, popup = paste("Ventilators Available:", Hospitals$ventilators, "<br>",
                                                                                                     "Beds Available:", Hospitals$BEDS, "<br>",
                                                                                                     "Negative Rooms:", Hospitals$negative_rooms, "<br>",
                                                                                                     "Shortages:", Hospitals$shortages, "<br>"))
})

###Generate output table###
output$table <- renderDataTable({
  Hospitals <- hospital_data()
  #select relevant columns to display
  Hospitals <- Hospitals %>% select(NAME:ZIP,ventilators, capacity, entry_date)
  
  datatable(Hospitals,
            options = list(lengthMenu = c(25,50,100,200)),
            selection = "single")
  
})