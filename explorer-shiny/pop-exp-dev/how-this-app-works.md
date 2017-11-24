# How the Population Explorer front end works

Author: Peter Ellis
Date:   27 November 2017

## Overview

### Introduction

The Population Explorer consists of three products, all of them experimental at the time of writing:

1. A [dimensionally modelled](http://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/dimensional-modeling-techniques/) datamart of annual and quarterly "rolled up" data with one observation per person-period-variable combination
2. An interactive web tool to explore the annual data in the datamart
3. A synthetic version 

This document explains the source code for the **interactive web tool** or web application, referred to as "the application" in this document.  The application is written in the [Shiny framework](https://shiny.rstudio.com/), an extension of the R statistical computing environment.

### What the application does

The application has four key steps:

1. The user interacts with widgets on a web page to select a type of analysis, variables to analyse and filter the data by, and hits a "refresh" button
2. The R server uses the user inputs to create an SQL query and sends it to the database to retrieve data, with as much aggregation occurring in the database as possible to minimise data transfers between servers
3. The R server performs analysis on the data including confidentialisation for [statistical disclosure control](https://en.wikipedia.org/wiki/Statistical_disclosure_control) as necessary, and generates summary graphics, tables, and explanatory text
4. These results are returned to the client an rendered in the web page.  The user can download a release-ready Excel version of tables, data and metadata, copy a PNG image to the clipboard, copy SQL for re-use in their own queries, or re-initiate the whole process.

The aim is to facilitate exploration of the data in the IDI.

### How the source code is structured

The codebase consists of a small number of files in R, SQL, CSS and JavaScript held in a single folder.

In the root directory, we have:

- `global.R` is run first, when a user initiates the application.  It loads necessary R packages and functionality, sets parameters such as which copy of the database to use, what minimum cell size of counts before suppressing them, and how high to make graphics in pixels.  It also creates appropriately structured R objects with information on the variables available in the database (which it interrogates to create those objects), for use in the user's widgets and in the server-side analysis.
- `ui.R` creates the user interface and performs steps 1 and 4 as described above under "What the application does"
- `server.R` runs server-side operations and performs steps 2 and 3

There are also two sub-directories:

- `src` holds two types of source code:
    - `*.R` files create functionality that has been abstracted out of `server.R` for maintainability purposes.  All these files are run by `global.R` during application initiation by the two lines of code that look like: `scripts <- list.files("src", pattern = "\\.R$", full.name = TRUE); devnull <- lapply(scripts, source)`
	- `*.sql` files are skeletons of SQL queries that are used by `server.R` as the basis for constructing actual legitimate queries.
- `www` holds assets for the web page and in particular:
    - `styles.css` is a cascading style sheet to give a Stats NZ look and feel to the web page.  Edit this to control things like fonts, heading sizes and colours for text other than that which is part of images.
	- `prism.css` controls the look of the SQL syntax highlighting in the browser.  Don't edit this file directly (well you can, but it's probably not worth the effort), but you can replace the file altogether with a different version from [http://prismjs.com/](http://prismjs.com/).  The currently chosen theme is "Solarized Light"
	- 'prism.js' is a JavaScript program that performs the actual syntax highlighting and has been downloaded from the same location.  
	- `SNZlogo1.png` is self-explanatory

## The user interface

This section describes how steps 1 and 4 (as described under "what the application does") are performed:

- user choices to direct analysis
- rendering results on the screen

## Building the SQL

This section describes how step 2  (as described under "what the application does") is performed:

- dynamically create a valid and nicely formatted SQL query to retrieve data from the datamart

## Analysis

This section describes how step 3 (as described under "what the application does") is performed:

- analysis including confidentialisation, and create summary tables, graphics and explanatory text




