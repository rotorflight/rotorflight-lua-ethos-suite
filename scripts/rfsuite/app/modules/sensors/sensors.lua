local i18n = rfsuite.i18n.get
local enableWakeup = false


local sensorList = {
    battery = {
        name = i18n("app.modules.sensors.battery"),
        sensors = {
            voltage = {
                name = i18n("app.modules.sensors.battery.voltage"),
                id = 3
            },
            current = {
                name = i18n("app.modules.sensors.battery.current"),
                id = 4
            },
            consumption = {
                name = i18n("app.modules.sensors.battery.consumption"),
                id = 5
            },
            chargelevel = {
                name = i18n("app.modules.sensors.battery.chargelevel"),
                id = 6
            },
            cellcount = {
                name = i18n("app.modules.sensors.battery.cellcount"),
                id = 7
            },
            cellvoltage = {
                name = i18n("app.modules.sensors.battery.cellvoltage"),
                id = 8
            },
            cellvoltages = {
                name = i18n("app.modules.sensors.battery.cellvoltages"),
                id = 9
            }
        }
    },
    voltage = {
        name = i18n("app.modules.sensors.voltage"),
        sensors = {
            esc = {
                name = i18n("app.modules.sensors.voltage.esc"),
                id = 42
            },
            bec = {
                name = i18n("app.modules.sensors.voltage.bec"),
                id = 43
            },
            bus = {
                name = i18n("app.modules.sensors.voltage.bus"),
                id = 44
            },
            mcu = {
                name = i18n("app.modules.sensors.voltage.mcu"),
                id = 45
            }
        },
    },
    current = {
        name = i18n("app.modules.sensors.current"),
        sensors = {
            esc = {
                name = i18n("app.modules.sensors.current.esc"),
                id = 46
            },
            bec = {
                name = i18n("app.modules.sensors.current.bec"),
                id = 47
            },
        }
    },
    temperature = {
        name = i18n("app.modules.sensors.temperature"),
        sensors = {
            esc = {
                name = i18n("app.modules.sensors.temperature.esc"),
                id = 50
            },
            bec = {
                name = i18n("app.modules.sensors.temperature.bec"),
                id = 51
            },
            mcu = {
                name = i18n("app.modules.sensors.temperature.mcu"),
                id = 52
            }
        }

    },
    esc1 = {
        name = i18n("app.modules.sensors.esc1"),
        sensors = {
            voltage = {
                name = i18n("app.modules.sensors.esc1.voltage"),
                id = 17
            },
            current = {
                name = i18n("app.modules.sensors.esc1.current"),
                id = 18
            },
            capacity = {
                name = i18n("app.modules.sensors.esc1.capacity"),
                id = 19
            },
            erpm = {
                name = i18n("app.modules.sensors.esc1.erpm"),
                id = 20
            },
            power = {
                name = i18n("app.modules.sensors.esc1.power"),
                id = 21
            },
            throttle = {
                name = i18n("app.modules.sensors.esc1.throttle"),
                id = 22
            },
            temp1 = {
                name = i18n("app.modules.sensors.esc1.temp1"),
                id = 23
            },
            temp2 = {
                name = i18n("app.modules.sensors.esc1.temp2"),
                id = 24
            },
            becvoltage = {
                name = i18n("app.modules.sensors.esc1.becvoltage"),
                id = 25
            },
            beccurrent = {
                name = i18n("app.modules.sensors.esc1.beccurrent"),
                id = 26
            },
            status = {
                name = i18n("app.modules.sensors.esc1.status"),
                id = 27
            },
            model = {
                name = i18n("app.modules.sensors.esc1.model"),
                id = 28
            }
        }
    },
    esc2 = {
        name = i18n("app.modules.sensors.esc2"),
        sensors = {
            voltage = {
                name = i18n("app.modules.sensors.esc2.voltage"),
                id = 30
            },
            current = {
                name = i18n("app.modules.sensors.esc2.current"),
                id = 31
            },
            capacity = {
                name = i18n("app.modules.sensors.esc2.capacity"),
                id = 32
            },
            erpm = {
                name = i18n("app.modules.sensors.esc2.erpm"),
                id = 33
            },
            power = {
                name = i18n("app.modules.sensors.esc2.power"),
                id = 34
            },
            throttle = {
                name = i18n("app.modules.sensors.esc2.throttle"),
                id = 35
            },
            temp1 = {
                name = i18n("app.modules.sensors.esc2.temp1"),
                id = 36
            },
            temp2 = {
                name = i18n("app.modules.sensors.esc2.temp2"),
                id = 37
            },
            becvoltage = {
                name = i18n("app.modules.sensors.esc2.becvoltage"),
                id = 38
            },
            beccurrent = {
                name = i18n("app.modules.sensors.esc2.beccurrent"),
                id = 39
            },
            status = {
                name = i18n("app.modules.sensors.esc2.status"),
                id = 40
            },
            model = {
                name = i18n("app.modules.sensors.esc2.model"),
                id = 41
            }
        }
    },
    rpm = {
        name = i18n("app.modules.sensors.rpm"),
        sensors = {
            headspeed = {
                name = i18n("app.modules.sensors.rpm.headspeed"),
                id = 60
            },
            tailspeed = {
                name = i18n("app.modules.sensors.rpm.tailspeed"),
                id = 61
            }
        }

    },
    barometer = {
        name = i18n("app.modules.sensors.barometer"),
        sensors = {
            altitude = {
                name = i18n("app.modules.sensors.barometer.altitude"),
                id = 58
            },
            variometer = {
                name = i18n("app.modules.sensors.barometer.variometer"),
                id = 59
            }
        }
    },
    gyro = {
        name = i18n("app.modules.sensors.gyro"),
        sensors = {
            heading = {
                name = i18n("app.modules.sensors.gyro.heading"),
                id = 57
            },
            attitudehighres = {
                name = i18n("app.modules.sensors.gyro.attitudehighres"),
                id = 64
            },
            accelx = {
                name = i18n("app.modules.sensors.gyro.accelx"),
                id = 69
            },
            accely = {
                name = i18n("app.modules.sensors.gyro.accely"),
                id = 70
            },
            accelz = {
                name = i18n("app.modules.sensors.gyro.accelz"),
                id = 71
            },
        }
    },
    gps = {
        name = i18n("app.modules.sensors.gps"),
        sensors = {
            sats = {
                name = i18n("app.modules.sensors.gps.sats"),
                id = 73
            },
            coordinates = {
                name = i18n("app.modules.sensors.gps.coordinates"),
                id = 77
            },
            altitude = {
                name = i18n("app.modules.sensors.gps.altitude"),
                id = 78
            },
            heading = {
                name = i18n("app.modules.sensors.gps.heading"),
                id = 79
            },
            speed = {
                name = i18n("app.modules.sensors.gps.speed"),
                id = 80
            }
        }
    },
    status = {
        name = i18n("app.modules.sensors.status"),
        sensors = {
            modelid = {
                name = i18n("app.modules.sensors.status.modelid"),
                id = 88
            },
            flightmode = {
                name = i18n("app.modules.sensors.status.flightmode"),
                id = 89
            },
            armingflags = {
                name = i18n("app.modules.sensors.status.armingflags"),
                id = 90
            },
            armingdisableflags = {
                name = i18n("app.modules.sensors.status.armingdisableflags"),
                id = 91
            },
            rescuestate = {
                name = i18n("app.modules.sensors.status.rescuestate"),
                id = 92
            },
            governorstate = {
                name = i18n("app.modules.sensors.status.governorstate"),
                id = 93
            },
            adjustmentfunctions = {
                name = i18n("app.modules.sensors.status.adjustmentfunctions"),
                id = 99
            }
        }
    },
    profile = {
        name = i18n("app.modules.sensors.profile"),
        sensors = {
            pidprofile = {
                name = i18n("app.modules.sensors.profile.pidprofile"),
                id = 95
            },
            rateprofile = {
                name = i18n("app.modules.sensors.profile.rateprofile"),
                id = 96
            }
        }
    },
    control = {
        name = i18n("app.modules.sensors.control"),
        sensors = {
            pitch = {
                name = i18n("app.modules.sensors.control.pitch"),
                id = 11
            },
            roll = {
                name = i18n("app.modules.sensors.control.roll"),
                id = 12
            },
            yaw = {
                name = i18n("app.modules.sensors.control.yaw"),
                id = 13
            },
            collective = {
                name = i18n("app.modules.sensors.control.collective"),
                id = 14
            },
            throttle = {
                name = i18n("app.modules.sensors.control.throttle"),
                id = 15
            }
        }
    },
    system = {
        name = i18n("app.modules.sensors.system"),
        sensors = {
            heartbeat = {
                name = i18n("app.modules.sensors.system.heartbeat"),
                id = 1
            },
            cpuload = {
                name = i18n("app.modules.sensors.system.cpuload"),
                id = 85
            },
            sysload = {
                name = i18n("app.modules.sensors.system.sysload"),
                id = 86
            },
            rtload = {
                name = i18n("app.modules.sensors.system.rtload"),
                id = 87
            }
        }
    },
    debug = {
        name = i18n("app.modules.sensors.debug"),
        sensors = {
            debug0 = {
                name = i18n("app.modules.sensors.debug.debug0"),
                id = 100
            },
            debug1 = {
                name = i18n("app.modules.sensors.debug.debug1"),
                id = 101
            },
            debug2 = {
                name = i18n("app.modules.sensors.debug.debug2"),
                id = 102
            },
            debug3 = {
                name = i18n("app.modules.sensors.debug.debug3"),
                id = 103
            },
            debug4 = {
                name = i18n("app.modules.sensors.debug.debug4"),
                id = 104
            },
            debug5 = {
                name = i18n("app.modules.sensors.debug.debug5"),
                id = 105
            },
            debug6 = {
                name = i18n("app.modules.sensors.debug.debug6"),
                id = 106
            },
            debug7 = {
                name = i18n("app.modules.sensors.debug.debug7"),
                id = 107
            },
        }

    }

}


local function openPage(pidx, title, script)
    enableWakeup = false
    rfsuite.app.triggers.closeProgressLoader = true
    form.clear()

    -- track page
    rfsuite.app.lastIdx    = pidx
    rfsuite.app.lastTitle  = title
    rfsuite.app.lastScript = script

    -- header
    rfsuite.app.ui.fieldHeader(
        i18n("app.modules.sensors.name") 
    )


end   

local function wakeup()
    if enableWakeup == false then return end

end

return {
    openPage = openPage,
    eepromWrite = true,
    reboot = false,
    wakeup = wakeup,
    API = {},
    navButtons = {
        menu   = true,
        save   = false,
        reload = false,
        tool   = false,
        help   = false,
    },    
}
