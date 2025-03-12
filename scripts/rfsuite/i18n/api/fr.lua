--[[
 * Copyright (C) Rotorflight Project
 *
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * Note. Some icons have been sourced from https://www.flaticon.com/
]] --

fr = {
    ACC_TRIM = {
        pitch = "Utiliser pour ajuster si l'hélico dérive dans l'un des modes stabilisés (angle, horizon, etc.).",
        roll = "Utiliser pour ajuster si l'hélico dérive dans l'un des modes stabilisés (angle, horizon, etc.).",
    },
    BATTERY_CONFIG = {
        batteryCapacity = "Capacité de votre batterie en milliampères-heure.",
        batteryCellCount = "Nombre de cellules dans votre batterie.",
        vbatmincellvoltage = "Tension minimale par cellule avant le déclenchement de l'alarme de basse tension.",
        vbatmaxcellvoltage = "Tension maximale par cellule avant le déclenchement de l'alarme de haute tension.",
        vbatfullcellvoltage = "Tension nominale d'une cellule complètement chargée.",
        vbatwarningcellvoltage = "Tension par cellule à laquelle l'alarme de basse tension commencera à sonner.",
    },
    ESC_SENSOR_CONFIG  = {
        half_duplex = "Mode half-duplex pour la télémétrie ESC",
        update_hz = "Taux de mise à jour de la télémétrie ESC",
        current_offset = "Ajustement de l'offset du capteur de courant",
        hw4_current_offset = "Ajustement de l'offset de courant Hobbywing v4",
        hw4_current_gain = "Ajustement du gain de courant Hobbywing v4",
        hw4_voltage_gain = "Ajustement du gain de tension Hobbywing v4",
        pin_swap = "Inverser les broches TX et RX pour la télémétrie ESC",
        voltage_correction = "Ajuster la correction de tension",
        current_correction = "Ajuster la correction de courant",
        consumption_correction = "Ajuster la correction de consommation",
        tbl_on = "Activé",
        tbl_off = "Désactivé",
    },
    FILTER_CONFIG = {
        gyro_lpf1_static_hz = "Fréquence de coupure du filtre passe-bas en Hz.",
        gyro_lpf2_static_hz = "Fréquence de coupure du filtre passe-bas en Hz.",
        gyro_soft_notch_hz_1 = "Fréquence centrale à laquelle le notch est appliqué.",
        gyro_soft_notch_cutoff_1 = "Largeur du filtre notch en Hz.",
        gyro_soft_notch_hz_2 = "Fréquence centrale à laquelle le notch est appliqué.",
        gyro_soft_notch_cutoff_2 = "Largeur du filtre notch en Hz.",
        gyro_lpf1_dyn_min_hz = "Filtre dynamique - fréquence de coupure minimale en Hz.",
        gyro_lpf1_dyn_max_hz = "Filtre dynamique - fréquence de coupure maximale en Hz."            
    },
    GOVERNOR_CONFIG = {
        gov_startup_time = "Temps constant pour le démarrage lent, en secondes, mesurant le temps de zéro à pleine vitesse de rotation.",
        gov_spoolup_time = "Temps constant pour l'augmentation progressive, en secondes, mesurant le temps de zéro à pleine vitesse de rotation.",
        gov_tracking_time = "Temps constant pour les changements de vitesse de rotation, en secondes, mesurant le temps de zéro à pleine vitesse de rotation.",
        gov_recovery_time = "Temps constant pour la récupération progressive, en secondes, mesurant le temps de zéro à pleine vitesse de rotation.",
        gov_handover_throttle = "Le gouverneur s'active au-dessus de ce %. En dessous, la commande des gaz est transmise directement à l'ESC.",
        gov_spoolup_min_throttle = "Gaz minimum à utiliser pour une montée progressive, en pourcentage. Pour les moteurs électriques, la valeur par défaut est 5%, pour le nitro, elle doit être réglée pour que l'embrayage commence à s'engager en douceur 10-15%.",           
        tbl_govmode_off = "DÉSACTIVÉ", 
        tbl_govmode_passthrough = "TRANSMISSION", 
        tbl_govmode_standard = "STANDARD", 
        tbl_govmode_mode1 = "MODE1", 
        tbl_govmode_mode2 = "MODE2",
    },
    MIXER_CONFIG = {
        tail_motor_idle = "Signal de gaz minimum envoyé au moteur de queue. Doit être juste assez élevé pour que le moteur ne s'arrête pas.",
        tail_center_trim = "Réglage du rotor de queue pour un lacet nul pour un pas variable, ou une accélération du moteur de queue pour un lacet nul.",
        swash_phase = "Décalage de phase pour les commandes du plateau cyclique.",
        swash_pitch_limit = "Quantité maximale de pas de pale combiné cyclique et collectif.",
        swash_trim_0 = "Réglage du plateau cyclique pour l'équilibrer lorsque des liens fixes sont utilisés.",
        swash_trim_1 = "Réglage du plateau cyclique pour l'équilibrer lorsque des liens fixes sont utilisés.",
        swash_trim_2 = "Réglage du plateau cyclique pour l'équilibrer lorsque des liens fixes sont utilisés.",
        swash_tta_precomp = "Précompensation du mixeur pour un lacet nul.",
        swash_geo_correction = "Ajuster s'il y a trop de collectif négatif ou trop de collectif positif.",
        collective_tilt_correction_pos = "Ajuster l'échelle de correction de l'inclinaison du collectif pour un pas collectif positif.",
        collective_tilt_correction_neg = "Ajuster l'échelle de correction de l'inclinaison du collectif pour un pas collectif négatif.",    
        tbl_cw = "Sens horaire",
        tbl_ccw = "Sens antihoraire",        
    }
}

return fr
