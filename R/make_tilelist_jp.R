library(tidycensus)
library(tidyverse)
library(sf)
library(spdep)
library(jsonlite)
library(mapboxapi)
library(simplecensus)
library(mapview)

MAPBOX_SECRET_TOKEN = "sk.eyJ1IjoieW1nYzE5IiwiYSI6ImNtOTlhOWtybDA5eXMyanNkb3Rjbm9tNzkifQ.KQj5b0Gd-JoHtFTcIzsz8w"
MAPBOX_USERNAME = "ymgc19"

# 東京のshpデータ
tokyo <- simplecensus::smc.read_census_shp(13) %>% 
  st_union() %>% 
  st_as_sf() %>% 
  st_transform(4326)
tokyo %>% mapview()

# 境界データ
shp <- simplecensus::smc.read_census_mesh_shp(13) %>% 
  st_transform(4326)
shp %>% glimpse()

shp <- shp %>% st_intersection(., tokyo) %>% 
  st_as_sf()
shp %>% mapview

# 統計データ
pop_data <- simplecensus::smc.read_census_mesh_2020(13)
pop_data %>% glimpse()

# GEOID に相当するキー（例：町丁コード、メッシュコードなど）で結合
d <- shp %>%
  left_join(pop_data, by="KEY_CODE") %>% 
  st_drop_geometry() %>% 
  mutate_all(as.numeric) %>%
  filter(!is.na(T001102004))

for (i in 1:nrow(d)) {
  target <- d[i, ]
  if (!is.na(target$HTKSAKI.x)) {
    hitokusaki <- target$HTKSAKI.x  # 合算先のKEY_CODE
    to_plus_pop <- target$T001102001
    to_plus_house <- target$T001102034
    # データフレームを更新（正しく代入する）
    d <- d %>%
      mutate(
        T001102001 = if_else(KEY_CODE == hitokusaki, T001102001 + to_plus_pop, T001102001),
        T001102034 = if_else(KEY_CODE == hitokusaki, T001102034 + to_plus_house, T001102034)
      )
  }
  print(i)
}

d <- d %>% 
  mutate(KEY_CODE = as.numeric(KEY_CODE)) %>% 
  left_join(shp %>% mutate(KEY_CODE = as.numeric(KEY_CODE)),
            by = "KEY_CODE") %>% 
  st_as_sf()

d %>% glimpse()
d %>% mapview




# ======================================================== ここまでデータの準備 ======================================================== #
# json化
g <- poly2nb(d, queen = FALSE)
ids <- d$KEY_CODE  
class(g) <- "list"
names(g) <- ids
g <- map(g, ~ ids[.])
write_json(g, "assets/tokyo_graph.json")

# タイル化
tippecanoe(d, "R/tokyo.mbtiles",
           layer_name="blocks",
           min_zoom=1, max_zoom=16,
           other_options="--coalesce-densest-as-needed --detect-shared-borders --use-attribute-for-id=KEY_CODE")


TILESET_ID <- "tokyo"
mbtile_name <- paste0("R/", TILESET_ID, ".mbtiles")

upload_tiles(
  input = mbtile_name,
  access_token = MAPBOX_SECRET_TOKEN,
  username = MAPBOX_USERNAME,
  tileset_id = TILESET_ID,
  tileset_name = paste0(TILESET_ID, "tokyo"),
  multipart = TRUE
)

spec <- read_json("assets/tokyo.json", simplifyVector = TRUE)
spec$units$bounds <- matrix(st_bbox(d), nrow = 2, byrow = TRUE)
spec$units$tilesets$source.url <- str_glue("mapbox://{MAPBOX_USERNAME}.{TILESET_ID}")
write_json(spec, paste0("assets/", TILESET_ID, ".json"))

