#
# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#


#-------------------
# https://github.com/Jean-Romain/PointCloudViewer
#
setwd("/Users/ethanchen/Desktop/2019SEM1/DataProject/MAMIF/R/Shiny_app_version1")
library(shiny)
library(lidR)
library(dplyr)
library(rgl)
# To plot raster layer in 3D.
library(rasterVis)
library(TreeLS)
library(styler)
source("../utils.R")


dataPath <- "/Users/ethanchen/Desktop/2019SEM1/DataProject/Shared_repo/"

MIN_DESITY_FOR_HOUGH_ALGO = 0.00000000000001

# 06-navlist.R

library(shiny)

ui <- navbarPage(title = "Phase 1 Forest Data Analysis",
                 
                ######################################################
                ## START SECTION 1 Preprocessing
                ######################################################
                 tabPanel(
                     # Application title
                     title = "Section 1 : data preprocessing",
                     
                     # Sidebar panel for inputs ----
                     sidebarPanel(width=6,
                                  h3("Loading las file."),
                                  # Input: Selector for choosing dataset ----
                                  selectInput(
                                      inputId = "dataset",
                                      label = "Choose a dataset:",
                                      choices = list.files(dataPath)
                                  ),
                                  
                                  # Input: Slider for the number of bins ----
                                  sliderInput(
                                      inputId = "distanceFromCenter",
                                      label = "Distance from center (meter):",
                                      min = 1,
                                      max = 50,
                                      value = 10
                                  )
                     ),
                     
                     mainPanel(
                         h2("Filter the ground"),
                         rglwidgetOutput("filtered_with_ground" , width = "600px", height = "600px"),    
                         h1("Flattern the terrian"),
                         h2("DTM"),
                         plotOutput(outputId = 'dtm'),
                         h2("Flattern"),
                         rglwidgetOutput("flatterned")
                         
                     )
                    
                 ),
                 
                
                ######################################################
                ## START SECTION 2 Canopy height model 
                ######################################################
                 
                 tabPanel(title = "Section 2 : canopy height model",
                          
                          p('Points-to-raster algorithm with a resolution of "q" meters replacing each
# point by a "r" meter radius circle of 8 points , higher the radius_length ,smoother the surface of the raster layer.'),
                          tabPanel(
                              # Application title
                              title = "Section 2 : Canopy height model",
                              
                              # Sidebar panel for inputs ----
                              sidebarPanel(width=6,
                                          
                                           # Input: Slider for the number of bins ----
                                           sliderInput(
                                               inputId = "chm_radius_length",
                                               label = "Radius Length ( r ) in meters",
                                               min = 0.1,
                                               max = 5,
                                               value = 0.2
                                           ), # Input: Slider for the number of bins ----
                                           sliderInput(
                                               inputId = "chm_resolution",
                                               label = "Resolution ( q ) in meters",
                                               min = 0.1,
                                               max = 1,
                                               value = 0.5
                                           )
                              )
                        ),
                        mainPanel(
                            h2("Canopy height model 2D"),
                            plotOutput(outputId = "canopy_height_model"),
                            h2("Canopy height model 3D"),
                            rglwidgetOutput(outputId = "canopy_height_model_3D" , height = "700px",width = "700px"),
                            h2("Tree counting (First attempt)"),
                            p("It implements an algorithm for tree detection based on a local maximum filter
Problem : changing the parameter ws (size of the moving window used to detect the local maxima) effect the number of treeID in the output. The higher the ws the lesser number of tree it identifys. However, the lower the ws, it identifies a tree a multiple trees."),
                            p('ws:Length or diameter of the moving window used to the detect the local maxima in the unit of the input data (usually meters)'),
                            sidebarPanel(width=12,
                                         
                                         # Input: Slider for the number of bins ----
                                         sliderInput(
                                             inputId = "ws",
                                             label = "Size of moving window ( WS ) in meters",
                                             min = 1,
                                             max = 10,
                                             value = 4
                                         )
                            ),
                            h2(textOutput("number_of_trees"))
                            ,
                            rglwidgetOutput(outputId = "count_tree_v1" , height = "700px",width = "700px")
                            ,
                            p("Compute the hull of each segmented tree. (note that the number of hulls could be less than the number of tree estimate)"),
                            plotOutput('tree_convex_hull')
                            
                            
                        )
                 ),
                
                ######################################################
                ## START SECTION 3 Tree trunk radius estimate
                ######################################################
                 
                tabPanel(title = "Section 3 : Tree trunk radius estimate",
                        
                             
                            
                         mainPanel(
                             h2(textOutput('number_of_tree_2')),
                            rglwidgetOutput('radius_plot',height = "700px",width = "700px"),
                              h2(textOutput('min_distance_between_trees')),
                             plotOutput(outputId = "treeXYLocation"),
                            dataTableOutput("radius_table")
                         )
                 
                )
)
                 


server <- function(input, output) {
    
    ######################################################
    ## START SECTION 1 Preprocessing
    ######################################################
    
    lasData <- reactive({
        lidR::readLAS(files = paste(dataPath, input$dataset, sep = ""))
    })
    
    smallData <- reactive({
        tmp <- pre_processing(las_df = lasData(), boundary = input$distanceFromCenter, shrunk_factor = 0.02)
        print("Input")
        print(input)
        
        tmp <- lasground(tmp, csf())
        return(tmp)
    })
    
    dtm <- reactive({
        grid_terrain(smallData() ,algorithm = knnidw(k = 6L, p = 2))
    })
    
    flatten_data <- reactive({
        d <- dtm()
        data <- smallData()
        data - d
    })
    
    
    output$filtered_with_ground <- renderPlaywidget({
        rgl.open(useNULL = F)

        small_dat <- smallData()
        
        points3d(x = small_dat@data$X, y = small_dat@data$Y, z = small_dat@data$Z, color = small_dat@data$Classification)
        
        axes3d()
        rglwidget()
    })
    
    output$dtm <- renderPlot({
        
        plot(dtm())
    })
    
    output$flatterned <- renderPlaywidget({
        rgl.open(useNULL = T)
        dat <- flatten_data()
        points3d(x = dat@data$X, y = dat@data$Y, z = dat@data$Z)
        axes3d()
        rglwidget()
        
    })
    
    ######################################################
    ## START SECTION 2 CHM
    ######################################################
    
    chm <- reactive({
        grid_canopy(flatten_data() ,input$chm_resolution, p2r(input$chm_radius_length))
    })
    
    output$canopy_height_model <- renderPlot({
        dat <- chm()
        col <- height.colors(30)
        plot(dat , col=col)
    })
    
    output$canopy_height_model_3D <- renderPlaywidget({
        rgl.open(useNULL = T)
        dat <- chm()
       
        plot3D(dat)
        rglwidget()
    })
    
    output$count_tree_v1 <- renderRglwidget({
        rgl.open(useNULL = T)
        dat <- flatten_data()
        
        ttops <- tree_detection(dat, lmf(ws=input$ws, hmin=2))
        # A SpatialPointsDataFrame with an attribute Z for the tree tops and treeID with an individual ID for each tree.
        
        x<-plot(dat)
        
        add_treetops3d(x, ttops)
        
        output$number_of_trees <- renderText({
            paste("Number of trees : " , length(ttops$treeID) )
        })
        
        rglwidget()
    })
    
    output$tree_convex_hull <- renderPlot({
      
      las <- tree_segmentation(flatten_data(), p2r_radius_length = input$chm_radius_length , lmf_ws = input$ws , algorithm = 2)
      metric<- tree_metrics(las,.stdtreemetrics)
      hulls<- tree_hulls(las)
      hulls@data<- dplyr::left_join(hulls@data, metric@data)
      spplot(hulls, "Z")
    })
    ######################################################
    ## START SECTION 3 Tree Trunk
    ######################################################
    
    treeMap1 <- reactive({
        #  ## sample points systematically in 3D
        # extract the tree map from a thinned point cloud
        # spacing numeric - voxel side length.
        thin = tlsSample(flatten_data(), voxelize(0.05))         
        
        # lower min_density -> more tree estimate
        #between 0 and 1 - minimum point density within a pixel evaluated on
        #the Hough Transform - i.e. only dense point clousters will undergo circle search.
        map1 = treeMap(thin, map.hough(min_density = MIN_DESITY_FOR_HOUGH_ALGO))
        return(list(thin , map1))
    })
    
    radiusDf <- reactive({
      df <- treeMap1()
      thin <- df[[1]]
      map1 <- df[[2]]
      small_dat_normal = stemPoints(thin, map1)
      result_df <- small_dat_normal@data %>% group_by(TreeID) %>% filter(TreeID > 0) %>% summarise(radius_estimate = max(Radius))
      
      return(result_df)
    })
    
   
    
   
    
    output$treeXYLocation <- renderPlot({
      
        map1 <- treeMap1()[[2]]
        output$number_of_tree_2 <- renderText({
            paste("Number of trees : " , length(unique(map1@data$TreeID)) )
        })
        
        
        # visualize tree map in 2D and 3D
        xymap = treePositions(map1 , plot =TRUE)
        
        output$min_distance_between_trees <- renderText({
        
          
          min_distances = c()
          count2 = 1
          for(i in seq(1,nrow(xymap))) {
            min_distance = c()
            p1 = xymap[i]
            count = 1
            for(j in seq(1,nrow(xymap))){
              
              if(i != j){
                p2 = xymap[j]
                min_distance[count] = distance(p1 , p2)
                count = count + 1
              }
            }
            min_distances[count2] <- min(min_distance)
            
            count2 = count2 + 1
          }
          
        
          paste("Mean distance between trees : (meters) " , mean(min_distances) )
        })
        
        
    })
    
    output$radius_plot <- renderRglwidget({
        rgl.open(useNULL = T)
        plot(treeMap1()[[2]])
        rglwidget()
    })
    
    output$radius_table <- renderDataTable({
      radiusDf()
    })
 
}

shinyApp(server = server, ui = ui)

