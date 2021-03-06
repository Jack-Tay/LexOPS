filter_opts_react <- reactive({
  if (gen_filterby_boxes_N() > 0) {
    lapply(1:gen_filterby_boxes_N(), function(i) {
      # collect input data about all the controls
      boxid <- sprintf("gen_filterby_%i", i)
      measure <- input[[sprintf("%s_v_measure", boxid)]]
      source <- input[[sprintf("%s_v_source", boxid)]]

      if (measure=="Length") {
        var <- "Length"
      } else if (grepl("^custom.", measure)) {
        var <- measure
      } else {
        possible_vars <- names(lexops_react_var_measures()[lexops_react_var_measures()==measure])
        possible_vars_sources <- sapply(possible_vars, function(v) LexOPS::var_to_source(v, first_cite = FALSE, standard_eval = TRUE))
        var <- possible_vars[possible_vars_sources == source]
      }

      selection <- if (input$preference_toleranceUI == "slider" | !is.numeric(lexops_react()[[var]])) {
        input[[sprintf("%s_v_selection", boxid)]]
      } else {
        c(input[[sprintf("%s_v_selection_1", boxid)]], input[[sprintf("%s_v_selection_2", boxid)]])
      }

      # return a list with everything we need
      list(var = var, selection = selection)
    })
  } else {
    NA
  }
})

split_opts_react <- reactive({
  if (gen_splitby_boxes_N() > 0) {
    lapply(1:gen_splitby_boxes_N(), function(i) {
      # collect input data about all the splits
      boxid <- sprintf("gen_splitby_%i", i)
      measure <- input[[sprintf("%s_v_measure", boxid)]]
      source <- input[[sprintf("%s_v_source", boxid)]]
      n_levels <- input[[sprintf("%s_v_n_levels", boxid)]]

      if (measure %in% c("Length", "Random") | grepl("^custom.", measure)) {
        var <- measure
      } else {
        possible_vars <- names(lexops_react_var_measures()[lexops_react_var_measures()==measure])
        possible_vars_sources <- sapply(possible_vars, function(v) LexOPS::var_to_source(v, first_cite = FALSE, standard_eval = TRUE))
        var <- possible_vars[possible_vars_sources == source]
      }

      selection <- if (measure == "Random") {
        NA
      } else if (input$preference_toleranceUI == "slider" | !is.numeric(lexops_react()[[var]])) {
        lapply(1:n_levels, function(lvl_i) input[[sprintf("%s_v_selection_%i", boxid, lvl_i)]])
      } else {
        lapply(1:n_levels, function(lvl_i) c(input[[sprintf("%s_v_selection_%i_1", boxid, lvl_i)]], input[[sprintf("%s_v_selection_%i_2", boxid, lvl_i)]]))
      }

      # return a list with everything we need
      list(var = var, selection = selection, n_levels = n_levels)
    })
  } else {
    NA
  }
})

control_opts_react <- reactive({
  if (gen_controlfor_boxes_N() > 0) {
    lapply(1:gen_controlfor_boxes_N(), function(i) {
      # collect input data about all the controls
      boxid <- sprintf("gen_controlfor_%i", i)
      measure <- input[[sprintf("%s_v_measure", boxid)]]
      source <- input[[sprintf("%s_v_source", boxid)]]

      if (measure=="Length") {
        var <- "Length"
      } else if (grepl("^custom.", measure)) {
        var <- measure
      } else {
        possible_vars <- names(lexops_react_var_measures()[lexops_react_var_measures()==measure])
        possible_vars_sources <- sapply(possible_vars, function(v) LexOPS::var_to_source(v, first_cite = FALSE, standard_eval = TRUE))
        var <- possible_vars[possible_vars_sources == source]
      }

      selection <- if (input$preference_toleranceUI == "slider" | !is.numeric(lexops_react()[[var]])) {
        input[[sprintf("%s_v_selection", boxid)]]
      } else {
        c(input[[sprintf("%s_v_selection_1", boxid)]], input[[sprintf("%s_v_selection_2", boxid)]])
      }

      # return a list with everything we need
      list(var = var, selection = selection)
    })
  } else {
    NA
  }
})

generated_stim <- reactive({

  # trigger regeneration if regenerate button is clicked
  input$gen_regenerate

  # get the filters
  filter_opts <- filter_opts_react()

  # get the splits
  split_opts <- split_opts_react()

  # get the controls
  control_opts <- control_opts_react()

  df <- lexops_react()

  # filters
  if (gen_filterby_boxes_N() > 0) {
    for (i in 1:gen_filterby_boxes_N()) {
      filt_var <- filter_opts[[i]]$var
      filt_sel <- filter_opts[[i]]$selection
      if (is.numeric(df[[filt_var]])) {
        # numeric filter
        df <- df %>%
          dplyr::filter(dplyr::between(!!(dplyr::sym(filt_var)), filt_sel[1], filt_sel[2]))
      } else {
        # categorical filter
        df <- df %>%
          dplyr::filter(!!(dplyr::sym(filt_var)) %in% filt_sel)
      }
    }
  }

  # splits
  if (gen_splitby_boxes_N() > 0) {
    for (i in 1:gen_splitby_boxes_N()) {
      if (split_opts[[i]]$var == "Random") {
        gen_seed <- if (input$preference_use_a_random_seed) input$preference_random_seed else NA
        df <- df %>%
          LexOPS::split_random(split_opts[[i]]$n_levels, seed = gen_seed)
      } else {
        df <- df %>%
          LexOPS::split_by(split_opts[[i]]$var, split_opts[[i]]$selection, standard_eval = TRUE)
      }
    }
  }

  # controls
  if (gen_controlfor_boxes_N() > 0 & gen_splitby_boxes_N() > 0) {
    for (i in 1:gen_controlfor_boxes_N()) {
      if (is.numeric(lexops_react()[[control_opts[[i]]$var]])) {
        df <- df %>%
          LexOPS::control_for(control_opts[[i]]$var, control_opts[[i]]$selection, standard_eval = TRUE)
      } else {
        df <- df %>%
          LexOPS::control_for(control_opts[[i]]$var, standard_eval = TRUE)
      }
    }
  }

  if (gen_controlfor_boxes_N() > 0 & gen_splitby_boxes_N() > 0) {
    n <- if (input$gen_stim_n_all) "all" else input$gen_stim_n
    match_null <- gen_match_null()

    shinyjs::html("gen_console", "Generating...")
    gen_seed <- if (input$preference_use_a_random_seed) input$preference_random_seed else NA
    out <- LexOPS::generate(df, n = n, match_null = match_null, seed = gen_seed, is_shiny = TRUE)

    if ((n!="all" & nrow(out) == n) | n=="all") {
      shinyjs::html("gen_console", " - Done!", add=TRUE)
    }

    out
  } else {
    if (gen_splitby_boxes_N() > 0 & gen_controlfor_boxes_N() == 0 & gen_filterby_boxes_N() == 0) {
      shinyjs::html("gen_console", "Only splits were specified. Will return the dataset with the specified splits.")
    } else if (gen_splitby_boxes_N() == 0 & gen_controlfor_boxes_N() > 0 & gen_filterby_boxes_N() == 0) {
      shinyjs::html("gen_console", "Only controls were specified, but controls require splits! This has no effect on the results.")
    } else if (gen_splitby_boxes_N() == 0 & gen_controlfor_boxes_N() == 0 & gen_filterby_boxes_N() > 0) {
      shinyjs::html("gen_console", "Only filters were specified. Will return the filtered dataset.")
    }

    df
  }

})

generated_stim_formatted <- reactive({

  if (gen_splitby_boxes_N() > 0 & gen_controlfor_boxes_N() > 0) {
    if (input$gen_data_format == "wide") {
      out <- generated_stim()
    } else if (input$gen_data_format == "long") {
      out <- LexOPS::long_format(generated_stim(), include = input$gen_res_include)
    }
  } else {
    if (input$gen_res_include == "all") {
      if (input$gen_data_format == "wide") {
        return(dplyr::select(generated_stim(), string))
      } else if (input$gen_data_format == "long") {
        return(generated_stim())
      }
    } else {
      out <- dplyr::select(generated_stim(), string)
    }
  }

  if (input$gen_res_include != "all") {
    # add filter variables if any (even if no splits or controls specified)
    if (gen_filterby_boxes_N() > 0 & input$gen_data_format == "long") {
      filter_vars <- sapply(1:gen_filterby_boxes_N(), function(i) {
        boxid <- sprintf("gen_filterby_%i", i)
        measure <- input[[sprintf("%s_v_measure", boxid)]]
        source <- input[[sprintf("%s_v_source", boxid)]]
        if (measure=="Length") {
          "Length"
        } else {
          possible_vars <- names(lexops_react_var_measures()[lexops_react_var_measures()==measure])
          possible_vars_sources <- sapply(possible_vars, function(v) LexOPS::var_to_source(v, first_cite = FALSE, standard_eval = TRUE))
          possible_vars[possible_vars_sources == source]
        }
      })
      out <- left_join(out, select(lexops_react(), c(string, unlist(filter_vars))), by = "string")
    }
    # if no controls are specified (so generate() function is never triggered), but the data is still split, add the variables used as splits too
    if (gen_controlfor_boxes_N() == 0 & gen_splitby_boxes_N() > 0) {
      split_vars <- sapply(1:gen_splitby_boxes_N(), function(i) {
        boxid <- sprintf("gen_splitby_%i", i)
        measure <- input[[sprintf("%s_v_measure", boxid)]]
        source <- input[[sprintf("%s_v_source", boxid)]]
        if (measure == "Random") {
          NULL
        } else if (measure=="Length") {
          "Length"
        } else {
          possible_vars <- names(lexops_react_var_measures()[lexops_react_var_measures()==measure])
          possible_vars_sources <- sapply(possible_vars, function(v) LexOPS::var_to_source(v, first_cite = FALSE, standard_eval = TRUE))
          possible_vars[possible_vars_sources == source]
        }
      })
      if (length(unlist(split_vars)) > 0) {
        out <- left_join(out, select(lexops_react(), c(string, unlist(split_vars))), by = "string")
      }
    }
  }

  out

})

# put in a data table
output$generated_stim_dt <- DT::renderDataTable({
  DT::datatable(generated_stim_formatted(), options=list(pageLength=25, scrollX=T), rownames=F)
})

# link to download
output$generated_stim_download <- downloadHandler(
  filename = 'generated_stimuli.csv',
  content = function(file) {
    withProgress(message="Writing stimuli to .csv file...", value=1, {
      write.csv(generated_stim_formatted(), file, row.names = FALSE)
    })
  }
)
