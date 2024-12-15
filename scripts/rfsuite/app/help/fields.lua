return {

    --
    -- servos.lua
    --
    servoMid = {t = "Servo center position pulse width."},
    servoMin = {t = "Servo negative travel limit."},
    servoMax = {t = "Servo positive travel limit."},
    servoScaleNeg = {t = "Servo negative scaling."},
    servoScalePos = {t = "Servo positive scaling."},
    servoRate = {t = "Servo PWM rate."},
    servoSpeed = {t = "Servo motion speed in milliseconds."},
    servoFlags = {t = "0 = Default, 1=Reverse, 2 = Geo Correction, 3 = Reverse + Geo Correction"},

    --
    -- mixer.lua
    --
    mixerSwashTrim = {t = "Swash trim to level the swash plate when using fixed links."},
    mixerTTAPrecomp = {t = "Mixer precomp for 0 yaw."}, -- ??? this is not named well in any of the RF LUAs
    mixerCollectiveGeoCorrection = {t = "Adjust if there is too much negative collective or too much positive collective."},
    mixerTotalPitchLimit = {t = "Maximum amount of combined cyclic and collective blade pitch."},
    mixerSwashPhase = {t = "Phase offset for the swashplate controls."},
    mixerTailMotorIdle = {t = "Minimum throttle signal sent to the tail motor. This should be set just high enough that the motor does not stop."},
    mixerTailMotorCenterTrim = {t = "Sets tail rotor trim for 0 yaw for variable pitch, or tail motor throttle for 0 yaw for motorized."},

    --
    -- governor.lua
    --
    govHandoverThrottle = {t = "Governor activates above this %. Below this the input throttle is passed to the ESC."},
    govStartupTime = {t = "Time constant for slow startup, in seconds, measuring the time from zero to full headspeed."},
    govSpoolupTime = {t = "Time constant for slow spoolup, in seconds, measuring the time from zero to full headspeed."},
    govTrackingTime = {t = "Time constant for headspeed changes, in seconds, measuring the time from zero to full headspeed."},
    govRecoveryTime = {t = "Time constant for recovery spoolup, in seconds, measuring the time from zero to full headspeed."},
    govAutoBailoutTime = {t = "Time constant for autorotation bailout spoolup, in seconds, measuring the time from zero to full headspeed."},
    govAutoTimeout = {t = "Timeout for ending autorotation and moving to normal idle and spoolup."},
    govAutoMinEntryTime = {t = "Minimum time with governor active before autorotation can be engaged."},
    govZeroThrottleTimeout = {t = "Timeout for missing throttle signal before governor shutoff. If signal returns within timeout, governor will perform recovery spoolup."},
    govLostHeadspeedTimeout = {t = "Timeout for missing RPM before spooling down. If RPM returns within timeout, the governor will perform recovery spoolup."},
    govHeadspeedFilterHz = {t = "Cutoff for the headspeed lowpass filter."},
    govVoltageFilterHz = {t = "Cutoff for the battery voltage lowpass filter."},
    govTTABandwidth = {t = "Cutoff for the TTA lowpass filter."},
    govTTAPrecomp = {t = "Cutoff for the cyclic/collective collective precomp lowpass filter."},
    govSpoolupThrottle = {t = "Minimum throttle to use for slow spoolup, in percent. For electric motors the default is 5%, for nitro this should be set so the clutch starts to engage for a smooth spoolup 10-15%."},
    --
    -- profile_governor.lua
    --
    govHeadspeed = {t = "Target headspeed for the current profile."},
    govMasterGain = {t = "Master PID loop gain."},
    govPGain = {t = "PID loop P-term gain."},
    govIGain = {t = "PID loop I-term gain."},
    govDGain = {t = "PID loop D-term gain."},
    govFGain = {t = "Feedforward gain."},

    govYawPrecomp = {t = "Yaw precompensation weight - how much yaw is mixed into the feedforward."},
    govCyclicPrecomp = {t = "Cyclic precompensation weight - how much cyclic is mixed into the feedforward."},
    govCollectivePrecomp = {t = "Collective precompensation weight - how much collective is mixed into the feedfoward."},

    govTTAGain = {t = "TTA gain applied to increase headspeed to control the tail in the negative direction (e.g. motorised tail less than idle speed)."},
    govTTALimit = {t = "TTA max headspeed increase over full headspeed."},

    govMaxThrottle = {t = "Maximum output throttle the governor is allowed to use."},
    govMinThrottle = {t = "Minimum output throttle the governor is allowed to use."},

    --
    -- accelerometer.lua
    --
    accelerometerTrim = {t = "Use to trim if the heli drifts in one of the stabilized modes (angle, horizon, etc.)."},

    --
    -- profile.lua
    --
    profilesErrorDecayGround = {t = "Bleeds off the current controller error when the craft is not airborne to stop the craft tipping over."},
    profilesErrorDecayGroundCyclicTime = {t = "Time constant for bleeding off cyclic I-term. Higher will stabilize hover, lower will drift."},
    profilesErrorDecayGroundCyclicLimit = {t = "Maximum bleed-off speed for cyclic I-term."},
    profilesErrorDecayGroundYawTime = {t = "Time constant for bleeding off yaw I-term."},
    profilesErrorDecayGroundYawLimit = {t = "Maximum bleed-off speed for yaw I-term."},
    profilesErrorLimit = {t = "Hard limit for the angle error in the PID loop. The absolute error and thus the I-term will never go above these limits."},
    profilesErrorHSIOffsetLimit = {t = "Hard limit for the High Speed Integral offset angle in the PID loop. The O-term will never go over these limits."},
    profilesErrorRotation = {t = "Rotates the current roll and pitch error terms around taw when the craft rotates. This is sometimes called Piro Compensation."},
    profilesItermRelaxType = {t = "Choose the axes in which this is active. RP: Roll, Pitch. RPY: Roll, Pitch, Yaw."},
    profilesItermRelax = {t = "Helps reduce bounce back after fast stick movements. Can cause inconsistency in small stick movements if too low."},
    profilesYawStopGainCW = {t = "Stop gain (PD) for clockwise rotation."},
    profilesYawStopGainCCW = {t = "Stop gain (PD) for counter-clockwise rotation."},
    profilesYawPrecompCutoff = {t = "Frequency limit for all yaw precompensation actions."},
    profilesYawFFCyclicGain = {t = "Cyclic feedforward mixed into yaw (cyclic-to-yaw precomp)."},
    profilesYawFFCollectiveGain = {t = "Collective feedforward mixed into yaw (collective-to-yaw precomp)."},
    profilesYawFFImpulseGain = {t = "An extra boost of yaw precomp on collective input."},
    profilesyawFFImpulseDecay = {t = "Decay time for the extra yaw precomp on collective input."},
    profilesPitchFFCollective = {t = "Increasing will compensate for the pitching up motion caused by tail drag when climbing."},
    profilesPIDBandwidth = {t = "PID loop overall bandwidth in Hz."},
    profilesPIDBandwidthDtermCutoff = {t = "D-term cutoff in Hz."},
    profilesPIDBandwidthBtermCutoff = {t = "B-term cutoff in Hz."},
    profilesCyclicCrossCouplingGain = {t = "Amount of compensation applied for pitch-to-roll decoupling."},
    profilesCyclicCrossCouplingRatio = {t = "Amount of roll-to-pitch compensation needed, vs. pitch-to-roll."},
    profilesCyclicCrossCouplingCutoff = {t = "Frequency limit for the compensation. Higher value will make the compensation action faster."},
    profilesAcroTrainerGain = {t = "Determines how aggressively the helicopter tilts back to the maximum angle (if exceeded) while in Acro Trainer Mode."},
    profilesAcroTrainerLimit = {t = "Limit the maximum angle the helicopter will pitch/roll to while in Acro Trainer Mode."},
    profilesAngleModeGain = {t = "Determines how aggressively the helicopter tilts back to level while in Angle Mode."},
    profilesAngleModeLimit = {t = "Limit the maximum angle the helicopter will pitch/roll to while in Angle mode."},
    profilesHorizonModeGain = {t = "Determines how aggressively the helicopter tilts back to level while in Horizon Mode."},

    --
    -- pids.lua
    --
    profilesProportional = {t = "How tightly the system tracks the desired setpoint."},
    profilesIntegral = {t = "How tightly the system holds its position."},
    profilesHSI = {t = "Used to prevent the craft from pitching up when flying at speed."},
    profilesDerivative = {t = "Strength of dampening to any motion on the system, including external influences. Also reduces overshoot."},
    profilesFeedforward = {t = "Helps push P-term based on stick input. Increasing will make response more sharp, but can cause overshoot."},
    profilesBoost = {t = "Additional boost on the feedforward to make the heli react more to quick stick movements."},

    --
    -- rates.lua
    --
    profilesRatesDynamicsTime = {t = "Increase or decrease the response time of the rate to smooth heli movements."},
    profilesRatesDynamicsAcc = {t = "Maximum acceleration of the craft in response to a stick movement."},

    --
    -- profile_rescue.lua
    --
    profilesRescueFlipMode = {t = "If rescue is activated while inverted, flip to upright - or remain inverted."},

    profilesRescuePullupCollective = {t = "Collective value for pull-up climb."},
    profilesRescuePullupTime = {t = "When rescue is activated, helicopter will apply pull-up collective for this time period before moving to flip or climb stage."},
    profilesRescueClimbCollective = {t = "Collective value for rescue climb."},
    profilesRescueClimbTime = {t = "Length of time the climb collective is applied before switching to hover."},
    profilesRescueHoverCollective = {t = "Collective value for hover."},
    profilesRescueFlipTime = {t = "If the helicopter is in rescue and is trying to flip to upright and does not within this time, rescue will be aborted."},
    profilesRescueExitTime = {t = "This limits rapid application of negative collective if the helicopter has rolled during rescue."},
    profilesRescueLevelGain = {t = "Determine how agressively the heli levels during rescue."},
    profilesRescueFlipGain = {t = "Determine how agressively the heli flips during inverted rescue."},
    profilesRescueMaxRate = {t = "Limit rescue roll/pitch rate. Larger helicopters may need slower rotation rates."},
    profilesRescueMaxAccel = {t = "Limit how fast the helicopter accelerates into a roll/pitch. Larger helicopters may need slower acceleration."},

    --
    -- filters.lua
    --
    gyroLowpassFilterCutoff = {t = "Lowpass filter cutoff frequency in Hz."},
    gyroLowpassFilterDynamicCutoff = {t = "Dynamic filter min/max cutoff in Hz."},
    gyroLowpassFilterCenter = {t = "Center frequency to which the notch is applied."},
    gyroDynamicNotchCount = {t = "Without RPM filters, 4-6 is recommended. With the RPM filters, 2-4 is recommended."},
    gyroDynamicNotchQ = {t = "Values between 2 and 4 recommended. Lower than 2 will increase filter delay and may degrade flight performance."},
    gyroDynamicNotchMinHz = {t = "Lowest incoming noise frequency to be filtered. Should be slightly below lowest main rotor fundamental, but no less than 20Hz."},
    gyroDynamicNotchMaxHz = {t = "Highest incoming noise frequency to be filtered. Should be 10-20% above highest tail rotor fundamental."},

    --
    -- motors.lua
    --
    motorMinThrottle = {t = "This PWM value is sent to the ESC/Servo at low throttle"},
    motorMaxThrottle = {t = "This PWM value is sent to the ESC/Servo at full throttle"},
    motorMinCommand = {t = "This PWM value is sent when the motor is stopped"},
    motorPollCount = {t = "The number of magnets on the motor bell."},
    motorGearRatioPinion = {t = "Motor Pinion Gear Tooth Count"},
    motorGearRatioMain = {t = "Main Gear Tooth Count"},
    motorGearRatioTailRear = {t = "Tail Gear Tooth Count"},
    motorGearRatioTailFront = {t = "Autorotation Gear Tooth Count"},

    --
    -- radio_config.lua
    --
    radioCenter = {t = "Stick center in microseconds (us)."},
    radioDeflection = {t = "Stick deflection from center in microseconds (us)."},
    radioArmThrottle = {t = "Throttle must be at or below this value in microseconds (us) to allow arming. Must be at least 10us lower than minimum throttle."},
    radioMinThrottle = {t = "Minimum throttle (0% throttle output) expected from radio, in microseconds (us)."},
    radioMaxThrottle = {t = "Maximum throttle (100% throttle output) expected from radio, in microseconds (us)."},
    radioCycDeadband = {t = "Deadband for cyclic control in microseconds (us)."},
    radioYawDeadband = {t = "Deadband for yaw control in microseconds (us)."},

    --
    -- sbusout_tool.lua
    --    
    sbusOutSource = {t = "Source id for the mix, counting from 0-15."},
    sbusOutMin = {t = "The minimum pwm value to send"},
    sbusOutMax = {t = "The maximum pwm value to send"},    
}
