#' Calculations for growth modifiers and productivity
#'
#' Internal functions for canopy productivity from light use and growth 
#'   modifiers for soil, vpd, etc.

canopy_production <- function(T_av, Ca, VPD, ASW, frost_days, stand_age, LAI, solar_rad, month, CounterforShrub, config, grass){ # DMG add Ca

  list2env(config$CanopyProduction, envir = environment())
  list2env(config$ShrubEffect, envir = environment())
  list2env(config$BiomassPartition, envir = environment())

    modifier_temperature = calc_modifier_temp(T_av, T_min, T_max, T_opt) 
    modifier_VPD = calc_modifier_VPD(VPD, CoeffCond)
    modifier_soilwater = calc_modifier_soilwater(ASW, MaxASW, SWconst0, SWpower0)
    modifier_nutrition = calc_modifier_soilnutrition(FR, fN0)
    modifier_frost = calc_modifier_frost(frost_days, kF)
    modifier_age = calc_modifier_age(stand_age, MaxAge, rAge, nAge)
    modifier_physiology = calc_physiological_modifier(modifier_VPD, modifier_soilwater, modifier_age)

    canopy_cover_list = calc_canopy_cover(stand_age, LAI, fullCanAge, canpower, k)
      list2env(canopy_cover_list, envir = environment())

    canopy_conductance = calc_canopy_conductance(T_av, LAI, modifier_physiology, TK2, TK3, MaxCond, LAIgcx)

    #DMG/
      #alphaPASS <- ifelse(test = grass == TRUE, yes = calc_modifier_co2(alpha = alpha, CO2 = Ca, Temperature = T_av), no = alpha)
    #/DMG

    canopy_production_list = calc_canopy_production(solar_rad, month, light_interception, canopy_cover, modifier_physiology, modifier_nutrition, modifier_temperature, modifier_frost, alpha, y)
      list2env(canopy_production_list, envir = environment())

    modifiers = c(modifier_temperature, modifier_VPD, modifier_soilwater, modifier_nutrition, modifier_frost, modifier_age, modifier_physiology)

    if(CounterforShrub == 0){
        LsOpen = LAI * KL
        LsClosed = Lsx * exp(-k * LAI)
        LAIShrub = min(LsOpen, LsClosed)
    } else if(CounterforShrub == 1){
        LAIShrub = Lsx * exp(-k * LAI)
    }
    if(LsClosed <= LsOpen){
        CounterforShrub = 1
    }

    canopy_production_list <- list(PAR = PAR, APAR = APAR, APARu = APARu, GPPmolc = GPPmolc, GPPdm = GPPdm, NPP = NPP, modifiers = modifiers, LAIShrub = LAIShrub, CounterforShrub = CounterforShrub, canopy_conductance = canopy_conductance)
  return(canopy_production_list)
}

calc_modifier_temp <- function(T_av, T_min, T_max, T_opt){
    if(T_av <= T_min | T_av >= T_max){
        res = 0
    } else {
        res = ((T_av - T_min) / (T_opt - T_min)) * ((T_max - T_av) / (T_max - T_opt)) ^ ((T_max - T_opt) / (T_opt - T_min))
    }
    return(res)
}

calc_modifier_VPD <- function(VPD, CoeffCond){
    res = exp(-1 * CoeffCond * VPD)
    return(res)
}

calc_modifier_soilwater <- function(ASW, MaxASW, SWconst, SWpower){
    moist_ratio = ASW / MaxASW
    res = 1 / (1 + ((1 - moist_ratio) / SWconst) ^ SWpower)
    return(res)
}

calc_modifier_soilnutrition <- function(FR, fN0){
    res = fN0 + (1 - fN0) * FR
    return(res)
}

calc_modifier_frost <- function(frost_days, kF){
    res = 1 - kF * (frost_days / 30)
    return(res)
}

calc_modifier_age <- function(stand_age, MaxAge, rAge, nAge){
    rel_age = stand_age / MaxAge
    res = (1 / (1 + (rel_age / rAge) ^ nAge))
    return(res)
}

calc_physiological_modifier <- function(modifier_VPD, modifier_soilwater, modifier_age){
    # calculate physiological modifier applied to conductance and APARu.
    res = min(modifier_VPD, modifier_soilwater) * modifier_age
    return(res)
}

###### python for trouble shoot
# def calc_canopy_cover(stand_age, LAI, fullCanAge, canpower, k):
#     # calc canopy cover and light interception.
#     canopy_cover = 1.0
#     if (fullCanAge > 0) and (stand_age < fullCanAge):
#         canopy_cover = (stand_age / fullCanAge) ** canpower
#     light_interception = (1 - (exp(-1 * k * LAI)))
# 
#     return canopy_cover, light_interception


calc_canopy_cover <- function(stand_age, LAI, fullCanAge, canpower, k){
    # calc canopy cover and light interception.
    canopy_cover = 1.0
    if(fullCanAge > 0 & stand_age < fullCanAge){
        canopy_cover = (stand_age / fullCanAge) ^ canpower
    }
    light_interception = (1 - (exp(-1 * k * LAI)))

    canopy_cover_list <- list(canopy_cover = canopy_cover, light_interception = light_interception)
    return(canopy_cover_list)
}

calc_canopy_conductance <- function(T_av, LAI, modifier_physiology, TK2, TK3, MaxCond, LAIgcx){
    # calculate canopy conductance from stomatal conductance
    # with added temperature modifier_ Liang Wei
    canopy_conductance = max(0, min(1, TK2 + TK3 * T_av)) * MaxCond * modifier_physiology * min(1, LAI / LAIgcx)
    if(canopy_conductance == 0){
        canopy_conductance = 0.0001
    }
    return(canopy_conductance)
}

calc_canopy_production <- function(solar_rad, month, light_interception, canopy_cover, modifier_physiology, modifier_nutrition, modifier_temperature, modifier_frost, alpha, y){
    # Determine gross and net biomass production
    # Calculate PAR, APAR, APARu and GPP

    RAD = solar_rad * get_days_in_month(month)        # MJ/m^2
    PAR = RAD * molPAR_MJ                      # mol/m^2
    APAR = PAR * light_interception * canopy_cover
    APARu = APAR * modifier_physiology
    alphaC = alpha * modifier_nutrition * modifier_temperature * modifier_frost
    GPPmolc = APARu * alphaC                   # mol/m^2
    GPPdm = (GPPmolc * gDM_mol) / 100          # tDM/ha
    NPP = GPPdm * y                     # tDM/ha - assumes constant respiratory rate

    canopy_production_list <- list(PAR = PAR, APAR = APAR, APARu = APARu, GPPmolc = GPPmolc, GPPdm = GPPdm, NPP = NPP)
    return(canopy_production_list)
}

Pa_ppm <- function(x){(x/101.325)*1000}
ppm_Pa <- function(x){(x/1000)*101.325}
      
# DMG proposed co2 modifier, not yet added to growth function
calc_modifier_co2 <- function(alpha, CO2, Temperature){
      a <- 0.8 # PAR absorbance
      alpha <- alpha # intrinsic quantum yield
      CiCa <- 0.8
#
      
      CO2 <- ppm_Pa(CO2)
      P_i <- CO2 * CiCa
      Q10 <- 0.57
      s25 <- 2600
      pO2 <- 21000
      s <- function(x){s25 * Q10 ^ ((x - 25)/ 10)}  
      I <- c(250:251) # incident PAR
    
      #A <- a * alpha * I * ((P_i - pO2 / (2 * s(Temperature))) / (P_i + 2 * pO2 / (2 * s(Temperature))))
      A1 <- (a * alpha * I[1] * ((P_i - pO2 / (2 * s(Temperature))) / (P_i + 2 * pO2 / (2 * s(Temperature)))))
      A2 <- (a * alpha * I[2] * ((P_i - pO2 / (2 * s(Temperature))) / (P_i + 2 * pO2 / (2 * s(Temperature)))))
      effective_LUE <- abs(A2-A1)

    return(effective_LUE)
}

back_calc_co2 <- function(effective_LUE, Temperature){
      a <- 0.8 # PAR absorbance
      alpha <- 0.085 # intrinsic quantum yield
      CiCa <- 0.8

     
      Q10 <- 0.57
      s25 <- 2600
      pO2 <- 21000
      s <- function(x){s25 * Q10 ^ ((x - 25)/ 10)}  
      I <- c(250:251) # incident PAR
    
      
      LE <- effective_LUE / (a * alpha)
      A <- pO2 / (2 * s(Temperature))
      B <- 2 * pO2 / (2 * s(Temperature))
      
      #x * LE + B * LE + A = x 
      CO2 = (-B * LE - A) / (LE - 1)
            CO2 <- Pa_ppm(CO2)/CiCa
            
    return(CO2)
}  
######################################