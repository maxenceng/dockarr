#!/bin/bash

cp homepage/* $CONFIG/homepage/
sed -i "s/IMAGE_PATH/{{.IMAGE_PATH}}/g" $CONFIG/homepage/settings.yaml

sed -i "s/JELLYSEERR_HREF/{{.JELLYSEERR_HREF}}/g" $CONFIG/homepage/services.yaml
sed -i "s/JELLYSEERR_KEY/{{.JELLYSEERR_KEY}}/g" $CONFIG/homepage/services.yaml

sed -i "s/JELLYFIN_HREF/{{.JELLYFIN_HREF}}/g" $CONFIG/homepage/services.yaml
sed -i "s/JELLYFIN_KEY/{{.JELLYFIN_KEY}}/g" $CONFIG/homepage/services.yaml

sed -i "s/SONARR_HREF/{{.SONARR_HREF}}/g" $CONFIG/homepage/services.yaml
sed -i "s/SONARR_KEY/{{.SONARR_KEY}}/g" $CONFIG/homepage/services.yaml

sed -i "s/SONARR_ANIME_HREF/{{.SONARR_ANIME_HREF}}/g" $CONFIG/homepage/services.yaml
sed -i "s/SONARR_ANIME_KEY/{{.SONARR_ANIME_KEY}}/g" $CONFIG/homepage/services.yaml

sed -i "s/RADARR_HREF/{{.RADARR_HREF}}/g" $CONFIG/homepage/services.yaml
sed -i "s/RADARR_KEY/{{.RADARR_KEY}}/g" $CONFIG/homepage/services.yaml

sed -i "s/RADARR_ANIME_HREF/{{.RADARR_ANIME_HREF}}/g" $CONFIG/homepage/services.yaml
sed -i "s/RADARR_ANIME_KEY/{{.RADARR_ANIME_KEY}}/g" $CONFIG/homepage/services.yaml

sed -i "s/PROWLARR_HREF/{{.PROWLARR_HREF}}/g" $CONFIG/homepage/services.yaml
sed -i "s/PROWLARR_KEY/{{.PROWLARR_KEY}}/g" $CONFIG/homepage/services.yaml

sed -i "s/TRANSMISSION_HREF/{{.TRANSMISSION_HREF}}/g" $CONFIG/homepage/services.yaml
sed -i "s/TRANSMISSION_KEY/{{.TRANSMISSION_KEY}}/g" $CONFIG/homepage/services.yaml

sed -i "s/BAZARR_HREF/{{.BAZARR_HREF}}/g" $CONFIG/homepage/services.yaml
sed -i "s/BAZARR_KEY/{{.BAZARR_KEY}}/g" $CONFIG/homepage/services.yaml

sed -i "s/STIRLING_HREF/{{.STIRLING_HREF}}/g" $CONFIG/homepage/services.yaml

sed -i "s/HOME_ASSISTANT_HREF/{{.HOME_ASSISTANT_HREF}}/g" $CONFIG/homepage/services.yaml
sed -i "s/HOME_ASSISTANT_KEY/{{.HOME_ASSISTANT_KEY}}/g" $CONFIG/homepage/services.yaml

sed -i "s/PIHOLE_HREF/{{.PIHOLE_HREF}}/g" $CONFIG/homepage/services.yaml
sed -i "s/PIHOLE_KEY/{{.PIHOLE_KEY}}/g" $CONFIG/homepage/services.yaml

sed -i "s/CLOUD_BEAVER_HREF/{{.CLOUD_BEAVER_HREF}}/g" $CONFIG/homepage/services.yaml

sed -i "s/PORTAINER_HREF/{{.PORTAINER_HREF}}/g" $CONFIG/homepage/services.yaml
sed -i "s/PORTAINER_KEY/{{.PORTAINER_KEY}}/g" $CONFIG/homepage/services.yaml

sed -i "s/JOAL_HREF/{{.JOAL_HREF}}/g" $CONFIG/homepage/services.yaml

sed -i "s/FILEGATOR_HREF/{{.FILEGATOR_HREF}}/g" $CONFIG/homepage/services.yaml

sed -i "s/MEALIE_HREF/{{.MEALIE_HREF}}/g" $CONFIG/homepage/services.yaml
sed -i "s/MEALIE_KEY/{{.MEALIE_KEY}}/g" $CONFIG/homepage/services.yaml

sed -i "s/VAULTWARDEN_HREF/{{.VAULTWARDEN_HREF}}/g" $CONFIG/homepage/services.yaml
