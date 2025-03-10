local labels = {}
local fields = {}

local activateWakeup = false

local mspapi = {
    api = {
        [1] = "PID_PROFILE",
    },
    formdata = {
        labels = {
            {t = rfsuite.i18n.get("app.modules.profile_pidcontroller.inflight_error_decay"), label = 2,  inline_size = 13.6},
            {t = rfsuite.i18n.get("app.modules.profile_pidcontroller.error_limit"),          label = 4,  inline_size = 8.15},
            {t = rfsuite.i18n.get("app.modules.profile_pidcontroller.hsi_offset_limit"),     label = 5,  inline_size = 8.15},
            {t = rfsuite.i18n.get("app.modules.profile_pidcontroller.iterm_relax"),         label = 6,  inline_size = 40.15},
            {t = rfsuite.i18n.get("app.modules.profile_pidcontroller.cutoff_point"),label = 15, inline_size = 8.15}
        },
        fields = {
            {t = rfsuite.i18n.get("app.modules.profile_pidcontroller.ground_error_decay"),                         mspapi = 1, apikey = "error_decay_time_ground"          },
            {t = rfsuite.i18n.get("app.modules.profile_pidcontroller.time"),               inline = 2, label = 2,  mspapi = 1, apikey = "error_decay_time_cyclic"},
            {t = rfsuite.i18n.get("app.modules.profile_pidcontroller.limit"),              inline = 1, label = 2,  mspapi = 1, apikey = "error_decay_limit_cyclic"},
            {t = rfsuite.i18n.get("app.modules.profile_pidcontroller.roll"),                  inline = 3, label = 4,  mspapi = 1, apikey = "error_limit_0"          },
            {t = rfsuite.i18n.get("app.modules.profile_pidcontroller.pitch"),                  inline = 2, label = 4,  mspapi = 1, apikey = "error_limit_1"          },
            {t = rfsuite.i18n.get("app.modules.profile_pidcontroller.yaw"),                  inline = 1, label = 4,  mspapi = 1, apikey = "error_limit_2"          },        
            {t = rfsuite.i18n.get("app.modules.profile_pidcontroller.roll"),                  inline = 3, label = 5,  mspapi = 1, apikey = "offset_limit_0"          },
            {t = rfsuite.i18n.get("app.modules.profile_pidcontroller.pitch"),                  inline = 2, label = 5,  mspapi = 1, apikey = "offset_limit_1"          },
            {t = rfsuite.i18n.get("app.modules.profile_pidcontroller.error_rotation"),                             mspapi = 1, apikey = "error_rotation", type = 1                      },
            {t = "",                   inline = 1, label = 6,  mspapi = 1, apikey = "iterm_relax_type", type = 1},
            {t = rfsuite.i18n.get("app.modules.profile_pidcontroller.roll"),                  inline = 3, label = 15, mspapi = 1, apikey = "iterm_relax_cutoff_0"  },
            {t = rfsuite.i18n.get("app.modules.profile_pidcontroller.pitch"),                  inline = 2, label = 15, mspapi = 1, apikey = "iterm_relax_cutoff_1"  },
            {t = rfsuite.i18n.get("app.modules.profile_pidcontroller.yaw"),                  inline = 1, label = 15, mspapi = 1, apikey = "iterm_relax_cutoff_2"  }
        }
    }                 
}

local function postLoad(self)
    rfsuite.app.triggers.closeProgressLoader = true
    activateWakeup = true
end

local function wakeup()

    if activateWakeup == true and rfsuite.tasks.msp.mspQueue:isProcessed() then

        -- update active profile
        -- the check happens in postLoad          
        if rfsuite.session.activeProfile ~= nil then
            rfsuite.app.formFields['title']:value(rfsuite.app.Page.title .. " #" .. rfsuite.session.activeProfile)
        end

    end

end

return {
    mspapi = mspapi,
    title = rfsuite.i18n.get("app.modules.profile_pidcontroller.name"),
    refreshOnProfileChange = true,
    reboot = false,
    eepromWrite = true,
    labels = labels,
    fields = fields,
    postLoad = postLoad,
    wakeup = wakeup,
    API = {},
}
