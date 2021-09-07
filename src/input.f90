! Copyright (C) 2018 ENVIRON (www.quantum-environment.org)
!
!    This file is part of Environ version 1.1
!
!    Environ 1.1 is free software: you can redistribute it and/or modify
!    it under the terms of the GNU General Public License as published by
!    the Free Software Foundation, either version 2 of the License, or
!    (at your option) any later version.
!
!    Environ 1.1 is distributed in the hope that it will be useful,
!    but WITHOUT ANY WARRANTY; without even the implied warranty of
!    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
!    GNU General Public License for more detail, either the file
!    `License' in the root directory of the present distribution, or
!    online at <http://www.gnu.org/licenses/>.
!
!----------------------------------------------------------------------------------------
!
! Authors: Oliviero Andreussi (Department of Physics, UNT)
!          Francesco Nattino  (THEOS and NCCR-MARVEL, EPFL)
!          Ismaila Dabo       (DMSE, Penn State)
!          Nicola Marzari     (THEOS and NCCR-MARVEL, EPFL)
!
!----------------------------------------------------------------------------------------
!>
!! This module contains all routines performing initialization and broadcast
!!
!----------------------------------------------------------------------------------------
MODULE environ_input
    !------------------------------------------------------------------------------------
    !
    USE env_base_io, ONLY: ionode, ionode_id, comm, environ_unit
    USE env_io
    USE env_mp, ONLY: env_mp_bcast
    USE env_char_ops, ONLY: env_uppercase, env_is_substring
    !
    USE environ_param, ONLY: DP, BOHR_RADIUS_ANGS, nsx
    !
    USE env_base_input
    !
    !------------------------------------------------------------------------------------
    !
    PRIVATE
    !
    PUBLIC :: env_read_input
    !
    !------------------------------------------------------------------------------------
CONTAINS
    !------------------------------------------------------------------------------------
    !>
    !! Routine for reading Environ input files. Uses built-in Namelist functionality
    !! and derived routines for cards (external charges and dielectric regions)
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE env_read_input(filename)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        CHARACTER(LEN=80), INTENT(IN) :: filename
        !
        LOGICAL :: ext
        INTEGER :: environ_unit_input
        !
        CHARACTER(LEN=80) :: sub_name = 'env_read_input'
        !
        !--------------------------------------------------------------------------------
        ! Open environ input file: environ.in
        !
        environ_unit_input = env_find_free_unit()
        INQUIRE (file=TRIM(filename), exist=ext)
        !
        IF (.NOT. ext) CALL env_errore(sub_name, 'Missing input file', 1)
        !
        OPEN (unit=environ_unit_input, file=TRIM(filename), status="old")
        !
        !--------------------------------------------------------------------------------
        ! Read values into local variables
        !
        CALL env_header('Reading input from '//TRIM(filename))
        !
        CALL env_divider(.FALSE.)
        !
        CALL environ_read_namelist(environ_unit_input)
        !
        CALL environ_read_cards(environ_unit_input)
        !
        CALL env_divider(.TRUE.)
        !
        CLOSE (environ_unit_input)
        !
        !--------------------------------------------------------------------------------
        ! Set verbosity and open debug file
        !
        IF (verbose >= 1) &
            OPEN (unit=environ_unit, file='environ.debug', status='unknown')
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE env_read_input
    !------------------------------------------------------------------------------------
    !>
    !! Sets default values for all variables and overwrites with provided input
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE environ_read_namelist(environ_unit_input)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        INTEGER, INTENT(IN) :: environ_unit_input
        !
        LOGICAL :: lboundary, lelectrostatic
        INTEGER :: ios
        !
        CHARACTER(LEN=80) :: sub_name = 'environ_read_namelist'
        !
        !--------------------------------------------------------------------------------
        ! Set defaults
        !
        CALL environ_defaults()
        !
        CALL boundary_defaults()
        !
        CALL electrostatic_defaults()
        !
        !--------------------------------------------------------------------------------
        ! &ENVIRON namelist
        !
        ios = 0
        !
        CALL env_header('Reading ENVIRON namelist')
        !
        IF (ionode) READ (environ_unit_input, environ, iostat=ios)
        !
        CALL env_mp_bcast(ios, ionode_id, comm)
        !
        IF (ios /= 0) CALL env_errore(sub_name, 'Missing ENVIRON namelist', ABS(ios))
        !
        CALL environ_bcast() ! broadcast &ENVIRON variables
        !
        CALL environ_checkin() ! check &ENVIRON variables
        !
        CALL fix_boundary(lboundary) ! TRUE/FALSE depending on &ENVIRON
        !
        !--------------------------------------------------------------------------------
        ! &BOUNDARY namelist (only if needed)
        !
        ios = 0
        !
        IF (ionode) THEN
            !
            IF (lboundary) THEN
                !
                CALL env_header('Reading BOUNDARY namelist')
                !
                READ (environ_unit_input, boundary, iostat=ios)
            ELSE
                CALL env_header('Skipping BOUNDARY namelist')
            END IF
            !
        END IF
        !
        CALL env_mp_bcast(ios, ionode_id, comm)
        !
        IF (ios /= 0) CALL env_errore(sub_name, 'Missing BOUNDARY namelist', ABS(ios))
        !
        CALL boundary_bcast() ! broadcast &BOUNDARY variables
        !
        CALL boundary_checkin() ! check &BOUNDARY variables
        !
        CALL set_environ_type() ! set up environment according to the boundary
        !
        CALL fix_electrostatic(lelectrostatic) ! TRUE/FALSE depending on &ENVIRON
        !
        !--------------------------------------------------------------------------------
        ! &ELECTROSTATIC namelist (only if needed)
        !
        ios = 0
        !
        IF (ionode) THEN
            !
            IF (lelectrostatic) THEN
                !
                CALL env_header('Reading ELECTROSTATIC namelist')
                !
                READ (environ_unit_input, electrostatic, iostat=ios)
            ELSE
                CALL env_header('Skipping ELECTROSTATIC namelist')
            END IF
            !
        END IF
        !
        CALL env_mp_bcast(ios, ionode_id, comm)
        !
        IF (ios /= 0) &
            CALL env_errore(sub_name, 'Missing ELECTROSTATIC namelist', ABS(ios))
        !
        CALL electrostatic_bcast() ! broadcast &ELECTROSTATIC variables
        !
        CALL set_electrostatic_problem() ! set up electrostatic problem
        !
        CALL electrostatic_checkin() ! check &ELECTROSTATIC variables
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE environ_read_namelist
    !------------------------------------------------------------------------------------
    !>
    !! Variables initialization for Namelist ENVIRON
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE environ_defaults()
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        environ_restart = .FALSE.
        verbose = 0
        environ_thr = 1.D-1
        environ_nskip = 1
        environ_type = 'input'
        !
        system_ntyp = 0
        system_dim = 0
        system_axis = 3
        !
        env_nrep = 0
        !
        env_electrostatic = .FALSE.
        atomicspread(:) = -0.5D0
        !
        env_static_permittivity = 1.D0
        env_optical_permittivity = 1.D0
        !
        env_surface_tension = 0.D0
        !
        env_pressure = 0.D0
        !
        env_confine = 0.D0
        !
        env_electrolyte_ntyp = 0
        electrolyte_linearized = .FALSE.
        electrolyte_entropy = 'full'
        cion(:) = 1.0D0
        cionmax = 0.0D0 ! if remains zero, pb or linpb
        rion = 0.D0
        zion(:) = 0.D0
        temperature = 300.0D0
        !
        sc_permittivity = 1.D0
        sc_carrier_density = 0.D0
        !
        env_external_charges = 0
        env_dielectric_regions = 0
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE environ_defaults
    !------------------------------------------------------------------------------------
    !>
    !! Variables initialization for Namelist BOUNDARY
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE boundary_defaults()
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        solvent_mode = 'electronic'
        !
        radius_mode = 'uff'
        alpha = 1.D0
        softness = 0.5D0
        solvationrad(:) = -3.D0
        !
        stype = 2
        rhomax = 0.005
        rhomin = 0.0001
        tbeta = 4.8
        !
        corespread(:) = -0.5D0
        !
        solvent_distance = 1.D0
        solvent_spread = 0.5D0
        !
        solvent_radius = 0.D0
        radial_scale = 2.D0
        radial_spread = 0.5D0
        filling_threshold = 0.825D0
        filling_spread = 0.02D0
        !
        field_awareness = 0.D0
        charge_asymmetry = -1.D0
        field_max = 10.D0
        field_min = 1.D0
        !
        electrolyte_mode = 'electronic'
        !
        electrolyte_distance = 0.D0
        electrolyte_spread = 0.5D0
        !
        sc_distance = 0.D0
        sc_spread = 0.5D0
        !
        electrolyte_rhomax = 0.005D0
        electrolyte_rhomin = 0.0001D0
        electrolyte_tbeta = 4.8D0
        !
        electrolyte_alpha = 1.D0
        electrolyte_softness = 0.5D0
        !
        derivatives = 'default'
        ifdtype = 1
        nfdpoint = 2
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE boundary_defaults
    !------------------------------------------------------------------------------------
    !>
    !! Variables initialization for Namelist ELECTROSTATIC
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE electrostatic_defaults()
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        problem = 'none'
        tol = 1.D-5
        !
        solver = 'none'
        auxiliary = 'none'
        step_type = 'optimal'
        step = 0.3D0
        maxstep = 200
        inner_solver = 'none'
        inner_tol = 1.D-10
        inner_maxstep = 200
        inner_mix = 0.5D0
        !
        mix_type = 'linear'
        ndiis = 1
        mix = 0.5D0
        !
        preconditioner = 'sqrt'
        screening_type = 'none'
        screening = 0.D0
        !
        core = 'fft'
        !
        pbc_dim = -3
        pbc_correction = 'none'
        pbc_axis = 3
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE electrostatic_defaults
    !------------------------------------------------------------------------------------
    !>
    !! Broadcast variables values for Namelist ENVIRON
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE environ_bcast()
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        CALL env_mp_bcast(environ_restart, ionode_id, comm)
        !
        CALL env_mp_bcast(verbose, ionode_id, comm)
        !
        CALL env_mp_bcast(environ_thr, ionode_id, comm)
        !
        CALL env_mp_bcast(environ_nskip, ionode_id, comm)
        !
        CALL env_mp_bcast(environ_type, ionode_id, comm)
        !
        CALL env_mp_bcast(system_ntyp, ionode_id, comm)
        !
        CALL env_mp_bcast(system_dim, ionode_id, comm)
        !
        CALL env_mp_bcast(system_axis, ionode_id, comm)
        !
        CALL env_mp_bcast(env_nrep, ionode_id, comm)
        !
        CALL env_mp_bcast(env_electrostatic, ionode_id, comm)
        !
        CALL env_mp_bcast(atomicspread, ionode_id, comm)
        !
        CALL env_mp_bcast(env_static_permittivity, ionode_id, comm)
        !
        CALL env_mp_bcast(env_optical_permittivity, ionode_id, comm)
        !
        CALL env_mp_bcast(env_surface_tension, ionode_id, comm)
        !
        CALL env_mp_bcast(env_pressure, ionode_id, comm)
        !
        CALL env_mp_bcast(env_confine, ionode_id, comm)
        !
        CALL env_mp_bcast(env_electrolyte_ntyp, ionode_id, comm)
        !
        CALL env_mp_bcast(electrolyte_linearized, ionode_id, comm)
        !
        CALL env_mp_bcast(electrolyte_entropy, ionode_id, comm)
        !
        CALL env_mp_bcast(cion, ionode_id, comm)
        !
        CALL env_mp_bcast(cionmax, ionode_id, comm)
        !
        CALL env_mp_bcast(rion, ionode_id, comm)
        !
        CALL env_mp_bcast(zion, ionode_id, comm)
        !
        CALL env_mp_bcast(temperature, ionode_id, comm)
        !
        CALL env_mp_bcast(sc_permittivity, ionode_id, comm)
        !
        CALL env_mp_bcast(sc_carrier_density, ionode_id, comm)
        !
        CALL env_mp_bcast(env_external_charges, ionode_id, comm)
        !
        CALL env_mp_bcast(env_dielectric_regions, ionode_id, comm)
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE environ_bcast
    !------------------------------------------------------------------------------------
    !>
    !! Broadcast variables values for Namelist BOUNDARY
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE boundary_bcast()
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        CALL env_mp_bcast(solvent_mode, ionode_id, comm)
        !
        CALL env_mp_bcast(stype, ionode_id, comm)
        !
        CALL env_mp_bcast(rhomax, ionode_id, comm)
        !
        CALL env_mp_bcast(rhomin, ionode_id, comm)
        !
        CALL env_mp_bcast(tbeta, ionode_id, comm)
        !
        CALL env_mp_bcast(radius_mode, ionode_id, comm)
        !
        CALL env_mp_bcast(alpha, ionode_id, comm)
        !
        CALL env_mp_bcast(softness, ionode_id, comm)
        !
        CALL env_mp_bcast(solvationrad, ionode_id, comm)
        !
        CALL env_mp_bcast(corespread, ionode_id, comm)
        !
        CALL env_mp_bcast(solvent_distance, ionode_id, comm)
        !
        CALL env_mp_bcast(solvent_spread, ionode_id, comm)
        !
        CALL env_mp_bcast(solvent_radius, ionode_id, comm)
        !
        CALL env_mp_bcast(radial_scale, ionode_id, comm)
        !
        CALL env_mp_bcast(radial_spread, ionode_id, comm)
        !
        CALL env_mp_bcast(filling_threshold, ionode_id, comm)
        !
        CALL env_mp_bcast(filling_spread, ionode_id, comm)
        !
        CALL env_mp_bcast(field_awareness, ionode_id, comm)
        !
        CALL env_mp_bcast(charge_asymmetry, ionode_id, comm)
        !
        CALL env_mp_bcast(field_max, ionode_id, comm)
        !
        CALL env_mp_bcast(field_min, ionode_id, comm)
        !
        CALL env_mp_bcast(electrolyte_mode, ionode_id, comm)
        !
        CALL env_mp_bcast(electrolyte_distance, ionode_id, comm)
        !
        CALL env_mp_bcast(electrolyte_spread, ionode_id, comm)
        !
        CALL env_mp_bcast(sc_distance, ionode_id, comm)
        !
        CALL env_mp_bcast(sc_spread, ionode_id, comm)
        !
        CALL env_mp_bcast(electrolyte_rhomax, ionode_id, comm)
        !
        CALL env_mp_bcast(electrolyte_rhomin, ionode_id, comm)
        !
        CALL env_mp_bcast(electrolyte_tbeta, ionode_id, comm)
        !
        CALL env_mp_bcast(electrolyte_alpha, ionode_id, comm)
        !
        CALL env_mp_bcast(electrolyte_softness, ionode_id, comm)
        !
        CALL env_mp_bcast(derivatives, ionode_id, comm)
        !
        CALL env_mp_bcast(ifdtype, ionode_id, comm)
        !
        CALL env_mp_bcast(nfdpoint, ionode_id, comm)
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE boundary_bcast
    !------------------------------------------------------------------------------------
    !>
    !! Broadcast variables values for Namelist ELECTROSTATIC
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE electrostatic_bcast()
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        CALL env_mp_bcast(problem, ionode_id, comm)
        !
        CALL env_mp_bcast(tol, ionode_id, comm)
        !
        CALL env_mp_bcast(solver, ionode_id, comm)
        !
        CALL env_mp_bcast(inner_solver, ionode_id, comm)
        !
        CALL env_mp_bcast(inner_tol, ionode_id, comm)
        !
        CALL env_mp_bcast(inner_maxstep, ionode_id, comm)
        !
        CALL env_mp_bcast(inner_mix, ionode_id, comm)
        !
        CALL env_mp_bcast(auxiliary, ionode_id, comm)
        !
        CALL env_mp_bcast(step_type, ionode_id, comm)
        !
        CALL env_mp_bcast(step, ionode_id, comm)
        !
        CALL env_mp_bcast(maxstep, ionode_id, comm)
        !
        CALL env_mp_bcast(mix_type, ionode_id, comm)
        !
        CALL env_mp_bcast(mix, ionode_id, comm)
        !
        CALL env_mp_bcast(ndiis, ionode_id, comm)
        !
        CALL env_mp_bcast(preconditioner, ionode_id, comm)
        !
        CALL env_mp_bcast(screening_type, ionode_id, comm)
        !
        CALL env_mp_bcast(screening, ionode_id, comm)
        !
        CALL env_mp_bcast(core, ionode_id, comm)
        !
        CALL env_mp_bcast(pbc_dim, ionode_id, comm)
        !
        CALL env_mp_bcast(pbc_correction, ionode_id, comm)
        !
        CALL env_mp_bcast(pbc_axis, ionode_id, comm)
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE electrostatic_bcast
    !------------------------------------------------------------------------------------
    !>
    !! Check input values for Namelist ENVIRON
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE environ_checkin()
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        INTEGER :: i
        LOGICAL :: allowed = .FALSE.
        !
        CHARACTER(LEN=20) :: sub_name = 'environ_checkin'
        !
        !--------------------------------------------------------------------------------
        ! General
        !
        IF (environ_restart) CALL env_write('Environ restarting')
        !
        IF (verbose < 0) CALL env_errore(sub_name, 'verbose out of range', 1)
        !
        IF (environ_thr < 0.0_DP) &
            CALL env_errore(sub_name, 'environ_thr out of range', 1)
        !
        IF (environ_nskip < 0) &
            CALL env_errore(sub_name, 'environ_nskip out of range', 1)
        !
        IF (env_nrep(1) < 0 .OR. env_nrep(2) < 0 .OR. env_nrep(3) < 0) &
            CALL env_errore(sub_name, 'env_nrep cannot be smaller than 0', 1)
        !
        !--------------------------------------------------------------------------------
        ! Type
        !
        allowed = .FALSE.
        !
        DO i = 1, SIZE(environ_type_allowed)
            IF (TRIM(environ_type) == environ_type_allowed(i)) allowed = .TRUE.
        END DO
        !
        IF (.NOT. allowed) CALL env_invalid_opt(sub_name, 'environ_type', environ_type)
        !
        !--------------------------------------------------------------------------------
        ! System
        !
        IF (system_ntyp < 0) CALL env_errore(sub_name, 'system_ntype out of range', 1)
        !
        IF (system_dim < 0 .OR. system_dim > 3) &
            CALL env_errore(sub_name, 'system_dim out of range', 1)
        !
        IF (system_axis < 1 .OR. system_axis > 3) &
            CALL env_errore(sub_name, 'system_axis out of range', 1)
        !
        !--------------------------------------------------------------------------------
        ! Physical quantities
        !
        IF (env_static_permittivity < 1.0_DP) &
            CALL env_errore(sub_name, 'env_static_permittivity out of range', 1)
        !
        IF (env_optical_permittivity < 1.0_DP) &
            CALL env_errore(sub_name, 'env_optical_permittivity out of range', 1)
        !
        IF (env_surface_tension < 0.0_DP) &
            CALL env_errore(sub_name, 'env_surface_tension out of range', 1)
        !
        IF (temperature < 0.0_DP) &
            CALL env_errore(sub_name, 'temperature out of range', 1)
        !
        !--------------------------------------------------------------------------------
        ! Electrolyte
        !
        allowed = .FALSE.
        !
        DO i = 1, SIZE(electrolyte_entropy_allowed)
            !
            IF (TRIM(electrolyte_entropy) == electrolyte_entropy_allowed(i)) &
                allowed = .TRUE.
            !
        END DO
        !
        IF (.NOT. allowed) &
            CALL env_invalid_opt(sub_name, 'electrolyte_entropy', electrolyte_entropy)
        !
        IF (env_electrolyte_ntyp < 0 .OR. env_electrolyte_ntyp == 1) &
            CALL env_errore(sub_name, 'env_electrolyte_ntyp out of range', 1)
        !
        DO i = 1, env_electrolyte_ntyp
            !
            IF (cion(i) < 0.D0) &
                CALL env_errore(sub_name, 'cion cannot be negative', 1)
            !
        END DO
        !
        IF (cionmax < 0.D0 .OR. rion < 0.D0) &
            CALL env_errore(sub_name, 'cionmax and rion cannot be negative', 1)
        !
        IF (cionmax > 0.D0 .AND. rion > 0.D0) &
            CALL env_errore(sub_name, 'Either cionmax or rion can be set, not both', 1)
        !
        !--------------------------------------------------------------------------------
        ! Semiconductor
        !
        allowed = .FALSE.
        !
        IF (sc_permittivity < 1.D0) &
            CALL env_errore(sub_name, 'sc_permittivity out of range', 1)
        !
        IF (sc_carrier_density < 0.D0) &
            CALL env_errore(sub_name, 'sc_carrier_density cannot be negative', 1)
        !
        !--------------------------------------------------------------------------------
        ! Externals/Regions
        !
        IF (env_external_charges < 0) &
            CALL env_errore(sub_name, 'env_external_charges out of range', 1)
        !
        IF (env_dielectric_regions < 0) &
            CALL env_errore(sub_name, 'env_dielectric_regions out of range', 1)
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE environ_checkin
    !------------------------------------------------------------------------------------
    !>
    !! Check input values for Namelist BOUNDARY
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE boundary_checkin()
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        INTEGER :: i
        LOGICAL :: allowed = .FALSE.
        !
        CHARACTER(LEN=20) :: sub_name = 'boundary_checkin'
        !
        !--------------------------------------------------------------------------------
        ! Solvent
        !
        allowed = .FALSE.
        !
        DO i = 1, SIZE(solvent_mode_allowed)
            IF (TRIM(solvent_mode) == solvent_mode_allowed(i)) allowed = .TRUE.
        END DO
        !
        IF (.NOT. allowed) CALL env_invalid_opt(sub_name, 'solvent_mode', solvent_mode)
        !
        IF (stype > 2) CALL env_errore(sub_name, 'stype out of range', 1)
        !
        IF (rhomax < 0.0_DP) CALL env_errore(sub_name, 'rhomax out of range', 1)
        !
        IF (rhomin < 0.0_DP) CALL env_errore(sub_name, 'rhomin out of range', 1)
        !
        IF (rhomax < rhomin) &
            CALL env_errore(sub_name, 'Inconsistent rhomax and rhomin', 1)
        !
        IF (tbeta < 0.0_DP) CALL env_errore(sub_name, 'tbeta out of range', 1)
        !
        allowed = .FALSE.
        !
        DO i = 1, SIZE(radius_mode_allowed)
            IF (TRIM(radius_mode) == radius_mode_allowed(i)) allowed = .TRUE.
        END DO
        !
        IF (.NOT. allowed) CALL env_invalid_opt(sub_name, 'radius_mode', radius_mode)
        !
        IF (alpha <= 0.0_DP) CALL env_errore(sub_name, 'alpha out of range', 1)
        !
        IF (softness <= 0.0_DP) CALL env_errore(sub_name, 'softness out of range', 1)
        !
        IF (solvent_spread <= 0.0_DP) &
            CALL env_errore(sub_name, 'solvent_spread out of range', 1)
        !
        IF (solvent_radius < 0.0_DP) &
            CALL env_errore(sub_name, 'solvent_radius out of range', 1)
        !
        IF (radial_scale < 1.0_DP) &
            CALL env_errore(sub_name, 'radial_scale out of range', 1)
        !
        IF (radial_spread <= 0.0_DP) &
            CALL env_errore(sub_name, 'radial_spread out of range', 1)
        !
        IF (filling_threshold <= 0.0_DP) &
            CALL env_errore(sub_name, 'filling_threshold out of range', 1)
        !
        IF (filling_spread <= 0.0_DP) &
            CALL env_errore(sub_name, 'filling_spread out of range', 1)
        !
        IF (field_awareness < 0.0_DP) &
            CALL env_errore(sub_name, 'field_awareness out of range', 1)
        !
        IF (ABS(charge_asymmetry) > 1.0_DP) &
            CALL env_errore(sub_name, 'charge_asymmetry out of range', 1)
        !
        IF (field_min < 0.0_DP) CALL env_errore(sub_name, 'field_min out of range', 1)
        !
        IF (field_max <= field_min) &
            CALL env_errore(sub_name, 'field_max out of range', 1)
        !
        !--------------------------------------------------------------------------------
        ! Electrolyte
        !
        allowed = .FALSE.
        !
        DO i = 1, SIZE(electrolyte_mode_allowed)
            IF (TRIM(electrolyte_mode) == electrolyte_mode_allowed(i)) allowed = .TRUE.
        END DO
        !
        IF (.NOT. allowed) &
            CALL env_invalid_opt(sub_name, 'electrolyte_mode', electrolyte_mode)
        !
        IF (electrolyte_distance < 0.0_DP) &
            CALL env_errore(sub_name, 'electrolyte_distance out of range', 1)
        !
        IF (electrolyte_spread <= 0.0_DP) &
            CALL env_errore(sub_name, 'electrolyte_spread out of range', 1)
        !
        IF (electrolyte_rhomax < 0.0_DP) &
            CALL env_errore(sub_name, 'electrolyte_rhomax out of range', 1)
        !
        IF (electrolyte_rhomin < 0.0_DP) &
            CALL env_errore(sub_name, 'electrolyte_rhomin out of range', 1)
        !
        IF (electrolyte_rhomax < electrolyte_rhomin) &
            CALL env_errore(sub_name, &
                            'Inconsistent electrolyte_rhomax and electrolyte_rhomin', 1)
        !
        IF (electrolyte_tbeta < 0.0_DP) &
            CALL env_errore(sub_name, 'electrolyte_tbeta out of range', 1)
        !
        IF (electrolyte_alpha <= 0.0_DP) &
            CALL env_errore(sub_name, 'electrolyte_alpha out of range', 1)
        !
        IF (electrolyte_softness <= 0.0_DP) &
            CALL env_errore(sub_name, 'electrolyte_softness out of range', 1)
        !
        !--------------------------------------------------------------------------------
        ! Semiconductor
        !
        IF (sc_distance < 0.0_DP) &
            CALL env_errore(sub_name, 'electrolyte_distance out of range', 1)
        !
        IF (sc_spread <= 0.0_DP) &
            CALL env_errore(sub_name, 'electrolyte_spread out of range', 1)
        !
        !--------------------------------------------------------------------------------
        ! Derivatives
        !
        allowed = .FALSE.
        !
        DO i = 1, SIZE(derivatives_allowed)
            IF (TRIM(derivatives) == derivatives_allowed(i)) allowed = .TRUE.
        END DO
        !
        IF (.NOT. allowed) CALL env_invalid_opt(sub_name, 'derivatives', derivatives)
        !
        CALL env_header('Checking boundary derivatives')
        !
        SELECT CASE (TRIM(solvent_mode))
            !
        CASE ('electronic', 'full', 'system', 'fa-electronic', 'fa-full')
            !
            SELECT CASE (TRIM(derivatives))
                !
            CASE ('default')
                derivatives = 'chain'
                !
                CALL env_default('derivatives', derivatives, 'SCCS default')
                !
            CASE ('highmem', 'lowmem')
                !
                CALL env_errore(sub_name, &
                                "Only 'fd', 'fft', or 'chain' are allowed &
                                &with electronic interfaces", 1)
                !
            END SELECT
            !
        CASE ('ionic', 'fa-ionic')
            !
            SELECT CASE (TRIM(derivatives))
                !
            CASE ('default')
                derivatives = 'lowmem'
                !
                CALL env_default('derivatives', derivatives, 'SSCS default')
                !
            CASE ('fd', 'chain')
                !
                CALL env_errore(sub_name, &
                                "Only 'highmem' or 'lowmem' are allowed &
                                &with electronic interfaces", 1)
                !
            END SELECT
            !
        END SELECT
        !
        !--------------------------------------------------------------------------------
        ! Finite differentiation
        !
        IF (ifdtype < 1) CALL env_errore(sub_name, 'ifdtype out of range', 1)
        !
        IF (nfdpoint < 1) CALL env_errore(sub_name, 'nfdpoint out of range', 1)
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE boundary_checkin
    !------------------------------------------------------------------------------------
    !>
    !! Check input values for Namelist ELECTROSTATIC
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE electrostatic_checkin()
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        INTEGER :: i
        LOGICAL :: allowed = .FALSE.
        !
        CHARACTER(LEN=20) :: sub_name = 'electrostatic_checkin'
        !
        !--------------------------------------------------------------------------------
        ! Problem
        !
        allowed = .FALSE.
        !
        DO i = 1, SIZE(problem_allowed)
            IF (TRIM(problem) == problem_allowed(i)) allowed = .TRUE.
        END DO
        !
        IF (.NOT. allowed) CALL env_invalid_opt(sub_name, 'problem', problem)
        !
        IF (tol <= 0.0_DP) CALL env_errore(sub_name, 'tolerance out of range', 1)
        !
        !--------------------------------------------------------------------------------
        ! Solver
        !
        allowed = .FALSE.
        !
        DO i = 1, SIZE(solver_allowed)
            IF (TRIM(solver) == solver_allowed(i)) allowed = .TRUE.
        END DO
        !
        IF (.NOT. allowed) CALL env_invalid_opt(sub_name, 'solver', solver)
        !
        !--------------------------------------------------------------------------------
        ! Auxiliary
        !
        allowed = .FALSE.
        !
        DO i = 1, SIZE(auxiliary_allowed)
            IF (TRIM(auxiliary) == auxiliary_allowed(i)) allowed = .TRUE.
        END DO
        !
        IF (.NOT. allowed) CALL env_invalid_opt(sub_name, 'auxiliary', auxiliary)
        !
        !--------------------------------------------------------------------------------
        ! Step
        !
        allowed = .FALSE.
        !
        DO i = 1, SIZE(step_type_allowed)
            IF (TRIM(step_type) == step_type_allowed(i)) allowed = .TRUE.
        END DO
        !
        IF (.NOT. allowed) CALL env_invalid_opt(sub_name, 'step_type', step_type)
        !
        IF (step <= 0.0_DP) CALL env_errore(sub_name, 'step out of range', 1)
        !
        IF (maxstep <= 1) CALL env_errore(sub_name, 'maxstep out of range', 1)
        !
        !--------------------------------------------------------------------------------
        ! Mixing
        !
        allowed = .FALSE.
        !
        DO i = 1, SIZE(mix_type_allowed)
            IF (TRIM(mix_type) == mix_type_allowed(i)) allowed = .TRUE.
        END DO
        !
        IF (.NOT. allowed) CALL env_invalid_opt(sub_name, 'mix_type', mix_type)
        !
        IF (ndiis <= 0) CALL env_errore(sub_name, 'ndiis out of range', 1)
        !
        IF (mix <= 0.0_DP) CALL env_errore(sub_name, 'mix out of range', 1)
        !
        !--------------------------------------------------------------------------------
        ! Preconditioner
        !
        allowed = .FALSE.
        !
        DO i = 1, SIZE(preconditioner_allowed)
            IF (TRIM(preconditioner) == preconditioner_allowed(i)) allowed = .TRUE.
        END DO
        !
        IF (.NOT. allowed) &
            CALL env_invalid_opt(sub_name, 'preconditioner', preconditioner)
        !
        !--------------------------------------------------------------------------------
        ! Screening
        !
        allowed = .FALSE.
        !
        DO i = 1, SIZE(screening_type_allowed)
            IF (TRIM(screening_type) == screening_type_allowed(i)) allowed = .TRUE.
        END DO
        !
        IF (.NOT. allowed) &
            CALL env_invalid_opt(sub_name, 'screening_type', screening_type)
        !
        IF (screening < 0.0_DP) CALL env_errore(sub_name, 'screening out of range', 1)
        !
        allowed = .FALSE.
        !
        !--------------------------------------------------------------------------------
        ! Core
        !
        DO i = 1, SIZE(core_allowed)
            IF (TRIM(core) == core_allowed(i)) allowed = .TRUE.
        END DO
        !
        IF (.NOT. allowed) CALL env_invalid_opt(sub_name, 'core', core)
        !
        !--------------------------------------------------------------------------------
        ! PBC correction
        !
        CALL env_header('Checking PBC correction')
        !
        allowed = .FALSE.
        !
        DO i = 1, SIZE(pbc_correction_allowed)
            IF (TRIM(pbc_correction) == pbc_correction_allowed(i)) allowed = .TRUE.
        END DO
        !
        IF (.NOT. allowed) &
            CALL env_invalid_opt(sub_name, 'pbc_correction', pbc_correction)
        !
        SELECT CASE (TRIM(pbc_correction))
            !
        CASE ('none')
            CALL env_default('pbc_correction', pbc_correction, 'default')
            !
        CASE ('gcs')
            !
            IF (electrolyte_distance == 0.0_DP) &
                CALL env_errore(sub_name, &
                                'electrolyte_distance must be set &
                                &(greater than zero) for gcs correction', 1)
            !
            IF (TRIM(electrolyte_mode) /= 'system') THEN
                electrolyte_mode = 'system'
                !
                CALL env_default('electrolyte_mode', electrolyte_mode, &
                                 "gcs correction requires 'system' boundary")
                !
            END IF
            !
        END SELECT
        !
        IF (pbc_dim < -3 .OR. pbc_dim > 3) &
            CALL env_errore(sub_name, 'pbc_dim out of range', 1)
        !
        IF (pbc_axis < 1 .OR. pbc_axis > 3) &
            CALL env_errore(sub_name, 'cell_axis out of range', 1)
        !
        !--------------------------------------------------------------------------------
        ! Inner solver
        !
        allowed = .FALSE.
        !
        DO i = 1, SIZE(inner_solver_allowed)
            IF (TRIM(inner_solver) == inner_solver_allowed(i)) allowed = .TRUE.
        END DO
        !
        IF (.NOT. allowed) CALL env_invalid_opt(sub_name, 'inner_solver', inner_solver)
        !
        IF (inner_mix <= 0.0_DP) CALL env_errore(sub_name, 'inner_mix out of range', 1)
        !
        IF (inner_tol <= 0.0_DP) CALL env_errore(sub_name, 'inner_tol out of range', 1)
        !
        IF (inner_maxstep <= 1) &
            CALL env_errore(sub_name, 'inner_maxstep out of range', 1)
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE electrostatic_checkin
    !------------------------------------------------------------------------------------
    !>
    !! Check if BOUNDARY needs to be read and reset defaults
    !! according to the ENVIRON namelist
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE fix_boundary(lboundary)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        LOGICAL, INTENT(OUT) :: lboundary
        !
        CHARACTER(LEN=20) :: sub_name = 'fix_boundary'
        !
        !--------------------------------------------------------------------------------
        !
        lboundary = .FALSE.
        !
        IF (environ_type /= 'input' .AND. environ_type /= 'vacuum') &
            lboundary = .TRUE.
        !
        IF (env_static_permittivity > 1.D0 .OR. &
            env_optical_permittivity > 1.D0) &
            lboundary = .TRUE.
        !
        IF (env_surface_tension > 0.D0) lboundary = .TRUE.
        !
        IF (env_pressure /= 0.D0) lboundary = .TRUE.
        !
        IF (env_confine /= 0.D0) lboundary = .TRUE.
        !
        IF (env_electrolyte_ntyp > 0) lboundary = .TRUE.
        !
        IF (env_dielectric_regions > 0) lboundary = .TRUE.
        !
        IF (sc_permittivity > 1.D0 .OR. sc_carrier_density > 0) &
            lboundary = .TRUE.
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE fix_boundary
    !------------------------------------------------------------------------------------
    !>
    !! Set values according to the environ_type keyword and boundary mode
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE set_environ_type()
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        CHARACTER(LEN=20) :: sub_name = 'set_environ_type'
        !
        !--------------------------------------------------------------------------------
        !
        IF (TRIM(ADJUSTL(environ_type)) == 'input') RETURN
        ! skip set up if read environ keywords from input
        !
        !--------------------------------------------------------------------------------
        ! Set physically meaningful global parameters
        !
        CALL env_header('Setting up '//TRIM(environ_type)//' environment ('// &
                       &'solvent mode = '//TRIM(solvent_mode)//')')
        !
        SELECT CASE (TRIM(ADJUSTL(environ_type)))
            !
        CASE ('vacuum') ! vacuum case is straightforward, all flags are off
            env_static_permittivity = 1.D0
            env_optical_permittivity = 1.D0
            env_surface_tension = 0.D0
            env_pressure = 0.D0
            !
            CALL env_default('env_static_permittivity', '1.D0', '')
            !
            CALL env_default('env_optical_permittivity', '1.D0', '')
            !
            CALL env_default('env_surface_tension', '0.D0', '')
            !
            CALL env_default('env_pressure', '0.D0', '')
            !
            RETURN
            !
        CASE ('water', 'water-cation', 'water-anion') ! water experimental permittivities
            env_static_permittivity = 78.3D0
            env_optical_permittivity = 1.D0 ! 1.776D0
            !
            CALL env_default('env_static_permittivity', '78.3D0', '')
            !
            CALL env_default('env_optical_permittivity', '1.D0', '')
            !
        CASE DEFAULT
            CALL env_errore(sub_name, 'Unrecognized value for environ_type', 1)
            !
        END SELECT
        !
        !--------------------------------------------------------------------------------
        ! Depending on the boundary mode, set fitted parameters
        !
        IF (TRIM(ADJUSTL(solvent_mode)) == 'electronic' .OR. &
            TRIM(ADJUSTL(solvent_mode)) == 'full') THEN
            !
            !----------------------------------------------------------------------------
            ! Self-consistent continuum solvation (SCCS)
            !
            SELECT CASE (TRIM(ADJUSTL(environ_type)))
                !
            CASE ('water') ! SCCS for neutrals
                env_surface_tension = 50.D0
                env_pressure = -0.35D0
                rhomax = 0.005
                rhomin = 0.0001
                !
                CALL env_default('env_surface_tension', '50.D0', '')
                !
                CALL env_default('env_pressure', '-0.35D0', '')
                !
                CALL env_default('rhomax', '0.005', '')
                !
                CALL env_default('rhomin', '0.0001', '')
                !
            CASE ('water-cation') ! SCCS for cations
                env_surface_tension = 5.D0
                env_pressure = 0.125D0
                rhomax = 0.0035
                rhomin = 0.0002
                !
                CALL env_default('env_surface_tension', '5.D0', '')
                !
                CALL env_default('env_pressure', '0.125D0', '')
                !
                CALL env_default('rhomax', '0.0035', '')
                !
                CALL env_default('rhomin', '0.0002', '')
                !
            CASE ('water-anion') ! SCCS for cations
                env_surface_tension = 0.D0
                env_pressure = 0.450D0
                rhomax = 0.0155
                rhomin = 0.0024
                !
                CALL env_default('env_surface_tension', '0.D0', '')
                !
                CALL env_default('env_pressure', '0.450D0', '')
                !
                CALL env_default('rhomax', '0.0155', '')
                !
                CALL env_default('rhomin', '0.0024', '')
                !
            END SELECT
            !
        ELSE IF (TRIM(ADJUSTL(solvent_mode)) == 'ionic' .OR. &
                 TRIM(ADJUSTL(solvent_mode)) == 'fa-ionic') THEN
            !
            !----------------------------------------------------------------------------
            ! Soft-sphere continuum solvation
            !
            radius_mode = 'uff'
            softness = 0.5D0
            env_surface_tension = 50.D0 ! NOTE THAT WE ARE USING THE
            env_pressure = -0.35D0 ! SET FOR CLUSTERS, AS IN SCCS
            !
            CALL env_default('radius_mode', radius_mode, '')
            !
            CALL env_default('softness', '0.5D0', '')
            !
            CALL env_default('env_surface_tension', '50.D0', '')
            !
            CALL env_default('env_pressure', '-0.35D0', '')
            !
            SELECT CASE (TRIM(ADJUSTL(environ_type)))
                !
            CASE ('water') ! SS for neutrals
                alpha = 1.12D0
                !
                CALL env_default('alpha', '1.12D0', '')
                !
            CASE ('water-cation') ! SS for cations
                alpha = 1.10D0
                !
                CALL env_default('alpha', '1.10D0', '')
                !
            CASE ('water-anion') ! SS for anions
                alpha = 0.98D0
                !
                CALL env_default('alpha', '0.98D0', '')
                !
            END SELECT
            !
        END IF
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE set_environ_type
    !------------------------------------------------------------------------------------
    !>
    !! Set values according to the &ENVIRON namelist
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE fix_electrostatic(lelectrostatic)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        LOGICAL, INTENT(OUT) :: lelectrostatic
        !
        CHARACTER(LEN=20) :: sub_name = 'fix_electrostatic'
        !
        !--------------------------------------------------------------------------------
        !
        lelectrostatic = env_electrostatic
        !
        IF (env_static_permittivity > 1.D0 .OR. env_optical_permittivity > 1.D0) &
            lelectrostatic = .TRUE.
        !
        IF (env_external_charges > 0) lelectrostatic = .TRUE.
        !
        IF (env_dielectric_regions > 0) lelectrostatic = .TRUE.
        !
        IF (env_electrolyte_ntyp > 0) lelectrostatic = .TRUE.
        !
        IF (sc_permittivity > 1.D0 .OR. sc_carrier_density > 0) &
            lelectrostatic = .TRUE.
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE fix_electrostatic
    !------------------------------------------------------------------------------------
    !>
    !! Set problem according to the ENVIRON and ELECTROSTATIC namelists
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE set_electrostatic_problem()
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        CHARACTER(LEN=80) :: sub_name = 'set_electrostatic_problem'
        !
        !--------------------------------------------------------------------------------
        !
        CALL env_header('Setting up electrostatic problem')
        !
        IF (env_electrolyte_ntyp > 0) THEN
            !
            IF (TRIM(pbc_correction) /= 'gcs') THEN
                !
                IF (electrolyte_linearized) THEN
                    !
                    IF (cionmax > 0.D0 .OR. rion > 0.D0) THEN
                        problem = 'linmodpb'
                        !
                        CALL env_default('problem', problem, '')
                        !
                    ELSE IF (problem == 'none') THEN
                        problem = 'linpb'
                        !
                        CALL env_default('problem', problem, '')
                        !
                    END IF
                    !
                    IF (solver == 'none') THEN
                        solver = 'cg'
                        !
                        CALL env_default('solver', solver, '')
                        !
                    END IF
                    !
                ELSE
                    !
                    IF (cionmax > 0.D0 .OR. rion > 0.D0) THEN
                        problem = 'modpb'
                        !
                        CALL env_default('problem', problem, '')
                        !
                    ELSE IF (problem == 'none') THEN
                        problem = 'pb'
                        !
                        CALL env_default('problem', problem, '')
                        !
                    END IF
                    !
                    IF (solver == 'none') THEN
                        solver = 'newton'
                        !
                        CALL env_default('solver', solver, '')
                        !
                    END IF
                    !
                    IF (inner_solver == 'none') THEN
                        inner_solver = 'cg'
                        !
                        CALL env_default('inner_solver', inner_solver, '')
                        !
                    END IF
                    !
                END IF
                !
            END IF
            !
        END IF
        !
        IF (env_static_permittivity > 1.D0 .OR. env_dielectric_regions > 0) THEN
            !
            IF (problem == 'none') THEN
                problem = 'generalized'
                !
                CALL env_default('problem', problem, '')
                !
            END IF
            !
            IF (TRIM(pbc_correction) /= 'gcs') THEN
                !
                IF (solver == 'none') THEN
                    solver = 'cg'
                    !
                    CALL env_default('solver', solver, '')
                    !
                END IF
                !
            ELSE
                !
                IF (solver /= 'fp') THEN
                    solver = 'fp'
                    !
                    CALL env_default('solver', solver, &
                                     'gcs correction requires fixed-point solver')
                    !
                END IF
                !
                IF (auxiliary == 'none') THEN
                    auxiliary = 'full'
                    !
                    CALL env_default('auxiliary', auxiliary, '')
                    !
                END IF
                !
            END IF
            !
        ELSE
            !
            IF (problem == 'none') THEN
                problem = 'poisson'
                !
                CALL env_default('problem', problem, '')
                !
            END IF
            !
            IF (solver == 'none') THEN
                solver = 'direct'
                !
                CALL env_default('solver', solver, '')
                !
            END IF
            !
        END IF
        !
        IF (.NOT. (problem == 'pb' .OR. &
                   problem == 'modpb' .OR. &
                   problem == 'generalized') &
            .AND. (inner_solver /= 'none')) &
            CALL env_errore(sub_name, 'Only pb or modpb problems allow inner solver', 1)
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE set_electrostatic_problem
    !------------------------------------------------------------------------------------
    !>
    !! Environ cards parsing routine
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE environ_read_cards(unit)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        INTEGER, INTENT(IN), OPTIONAL :: unit
        !
        CHARACTER(LEN=256) :: input_line
        CHARACTER(LEN=80) :: card
        LOGICAL :: tend
        INTEGER :: i, local_unit
        !
        CHARACTER(LEN=80) :: sub_name = 'environ_read_cards'
        !
        !--------------------------------------------------------------------------------
        ! Set default READ unit if none provided
        !
        IF (PRESENT(unit)) THEN
            local_unit = unit
        ELSE
            local_unit = 5
        END IF
        !
        !=-----------------------------------------------------------------------------=!
        !  START OF LOOP
        !=-----------------------------------------------------------------------------=!
        !
100     CALL env_read_line(local_unit, input_line, end_of_file=tend)
        !
        !--------------------------------------------------------------------------------
        ! Skip blank/comment lines (REDUNDANT)
        !
        IF (tend) GOTO 120
        !
        READ (input_line, *) card
        !
        !--------------------------------------------------------------------------------
        ! Force uppercase
        !
        input_line = env_uppercase(input_line)
        !
        !--------------------------------------------------------------------------------
        ! Read cards
        !
        IF (TRIM(card) == 'EXTERNAL_CHARGES') THEN
            CALL card_external_charges(local_unit, input_line)
        ELSE IF (TRIM(card) == 'DIELECTRIC_REGIONS') THEN
            CALL card_dielectric_regions(local_unit, input_line)
        ELSE IF (ionode) THEN
            CALL env_warning('card '//TRIM(input_line)//' ignored')
        END IF
        !
        !=-----------------------------------------------------------------------------=!
        ! END OF LOOP
        !=-----------------------------------------------------------------------------=!
        !
        GOTO 100
        !
120     CONTINUE
        !
        !--------------------------------------------------------------------------------
        ! Final check
        !
        IF (env_external_charges > 0 .AND. .NOT. taextchg) &
            CALL env_errore(sub_name, 'Missing card external_charges', 1)
        !
        IF (env_dielectric_regions > 0 .AND. .NOT. taepsreg) &
            CALL env_errore(sub_name, 'Missing card dielectric_regions', 1)
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE environ_read_cards
    !------------------------------------------------------------------------------------
    !>
    !! Description of the allowed input CARDS
    !!
    !! EXTERNAL_CHARGES (unit_option)
    !!
    !!   set external fixed charge densities and their shape
    !!
    !! Syntax:
    !!
    !!    EXTERNAL_CHARGES (unit_option)
    !!      charge(1)  x(1) y(1) z(1)  spread(1) dim(1)  axis(1)
    !!       ...       ...        ...      ...        ...
    !!      charge(n)  x(n) y(n) z(n)  spread(n) dim(n)  axis(n)
    !!
    !! Example:
    !!
    !! EXTERNAL_CHARGES (bohr)
    !!  1.0  0.0  0.0  0.0  [0.5  2  1]
    !! -1.0  0.0  0.0  5.0  [0.5  2  1]
    !!
    !! Where:
    !!
    !!   unit_option == bohr       positions are given in Bohr (DEFAULT)
    !!   unit_option == angstrom   positions are given in Angstrom
    !!
    !!      charge(i) ( real )       total charge of the density
    !!      x/y/z(i)  ( real )       cartesian position of the density
    !!      spread(i) ( real )       gaussian spread of the density (in bohr, optional, default=0.5)
    !!      dim(i)    ( integer )    0/1/2 point/line/plane of charge (optional, default=0)
    !!      axis(i)   ( integer )    1/2/3 for x/y/z direction of line/plane (optional, default=3)
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE card_external_charges(unit, input_line)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        INTEGER, INTENT(IN) :: unit
        !
        CHARACTER(LEN=256) :: input_line
        INTEGER :: ie, ix, ierr, nfield
        LOGICAL :: tend
        CHARACTER(LEN=4) :: lb_pos
        CHARACTER(LEN=256) :: field_str
        !
        CHARACTER(LEN=80) :: sub_name = 'card_external_charges'
        !
        !--------------------------------------------------------------------------------
        !
        CALL env_header('Reading EXTERNAL_CHARGES card')
        !
        !--------------------------------------------------------------------------------
        ! Validate input
        !
        IF (taextchg) CALL env_errore(sub_name, 'Two occurrences', 2)
        !
        IF (env_external_charges > nsx) &
            CALL env_errore(sub_name, 'nsx out of range', env_external_charges)
        !
        CALL allocate_input_extcharge(env_external_charges)
        !
        IF (env_is_substring("BOHR", input_line)) THEN
            extcharge_units = 'bohr'
        ELSE IF (env_is_substring("ANGSTROM", input_line)) THEN
            extcharge_units = 'angstrom'
        ELSE
            !
            IF (TRIM(ADJUSTL(input_line)) /= 'EXTERNAL_CHARGES') &
                CALL env_errore(sub_name, &
                                'Invalid units for EXTERNAL_CHARGES: '//input_line, 1)
            !
            extcharge_units = 'bohr'
            !
            CALL env_default('charge units', extcharge_units, 'default')
            !
        END IF
        !
        !--------------------------------------------------------------------------------
        ! Parse card input
        !
        DO ie = 1, env_external_charges
            !
            CALL env_read_line(unit, input_line, end_of_file=tend)
            !
            IF (tend) &
                CALL env_errore(sub_name, 'End of file reading external charges', ie)
            !
            CALL env_field_count(nfield, input_line)
            !
            !----------------------------------------------------------------------------
            ! Read field 1 (total charge of the external density)
            !
            CALL env_get_field(1, field_str, input_line)
            !
            READ (field_str, *) extcharge_charge(ie)
            !
            !----------------------------------------------------------------------------
            ! Read fields 2-4 (x-y-z position of external density)
            !
            CALL env_get_field(2, field_str, input_line)
            !
            READ (field_str, *) extcharge_pos(1, ie)
            !
            CALL env_get_field(3, field_str, input_line)
            !
            READ (field_str, *) extcharge_pos(2, ie)
            !
            CALL env_get_field(4, field_str, input_line)
            !
            READ (field_str, *) extcharge_pos(3, ie)
            !
            !----------------------------------------------------------------------------
            ! Optionally read field 5 (spread of the density)
            !
            IF (nfield >= 5) THEN
                !
                CALL env_get_field(5, field_str, input_line)
                !
                READ (field_str, *) extcharge_spread(ie)
                !
                IF (extcharge_spread(ie) < 0.D0) &
                    CALL env_errore(sub_name, 'Spread must be positive', ie)
                !
            ELSE
                CALL env_default('charge spread', '0.5 (a.u.)', 'default')
            END IF
            !
            !----------------------------------------------------------------------------
            ! Optionally read field 6 and 7 (dimensionality and direction)
            !
            IF (nfield >= 6) THEN
                !
                CALL env_get_field(6, field_str, input_line)
                !
                READ (field_str, *) extcharge_dim(ie)
                !
                IF (extcharge_dim(ie) < 0 .OR. extcharge_dim(ie) > 2) &
                    CALL env_errore(sub_name, 'Wrong excharge dimension', ie)
                !
                IF (extcharge_dim(ie) > 0) THEN
                    !
                    IF (nfield == 6) THEN
                        CALL env_default('axis', '3 (z-axis)', 'default')
                    ELSE
                        !
                        CALL env_get_field(7, field_str, input_line)
                        !
                        READ (field_str, *) extcharge_axis(ie)
                        !
                        IF (extcharge_axis(ie) < 0 .OR. extcharge_axis(ie) > 3) &
                            CALL env_errore(sub_name, 'Wrong excharge axis', ie)
                        !
                    END IF
                    !
                END IF
                !
            ELSE
                CALL env_default('charge dimensions', '0', 'default')
            END IF
            !
        END DO
        !
        !--------------------------------------------------------------------------------
        ! Convert to atomic units
        !
        taextchg = .TRUE.
        !
        DO ie = 1, env_external_charges
            !
            DO ix = 1, 3
                CALL convert_length(extcharge_units, extcharge_pos(ix, ie))
            END DO
            !
            CALL convert_length(extcharge_units, extcharge_spread(ie))
            !
        END DO
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE card_external_charges
    !------------------------------------------------------------------------------------
    !>
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE allocate_input_extcharge(external_charges)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        INTEGER, INTENT(IN) :: external_charges
        !
        !--------------------------------------------------------------------------------
        !
        IF (ALLOCATED(extcharge_dim)) DEALLOCATE (extcharge_dim)
        !
        IF (ALLOCATED(extcharge_axis)) DEALLOCATE (extcharge_axis)
        !
        IF (ALLOCATED(extcharge_charge)) DEALLOCATE (extcharge_charge)
        !
        IF (ALLOCATED(extcharge_spread)) DEALLOCATE (extcharge_spread)
        !
        IF (ALLOCATED(extcharge_pos)) DEALLOCATE (extcharge_pos)
        !
        ALLOCATE (extcharge_dim(external_charges))
        ALLOCATE (extcharge_axis(external_charges))
        ALLOCATE (extcharge_charge(external_charges))
        ALLOCATE (extcharge_spread(external_charges))
        ALLOCATE (extcharge_pos(3, external_charges))
        !
        extcharge_dim = 0
        extcharge_axis = 3
        extcharge_charge = 0.0_DP
        extcharge_spread = 0.5_DP
        extcharge_pos = 0.0_DP
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE allocate_input_extcharge
    !------------------------------------------------------------------------------------
    !>
    !! Description of the allowed input CARDS
    !!
    !! DIELECTRIC_REGIONS (unit_option)
    !!
    !!   set fixed dielectric regions and their shape
    !!
    !! Syntax:
    !!
    !!    DIELECTRIC_REGIONS (unit_option)
    !!      epsilon0(1) epsilonopt(1) x(1) y(1) z(1)  width(1) spread(1) dim(1)  axis(1)
    !!       ...       ...        ...      ...        ...
    !!      epsilon0(n) epsilonopt(n) x(n) y(n) z(n)  width(n) spread(n) dim(n)  axis(n)
    !!
    !! Example:
    !!
    !! DIELECTRIC_REGIONS (bohr)
    !!  80.0  2.0   0.0  0.0  10.0   5.0  1.0  2  3
    !!
    !! Where:
    !!
    !!   unit_option == bohr       positions are given in Bohr (DEFAULT)
    !!   unit_option == angstrom   positions are given in Angstrom
    !!
    !!      epsilon0(i)   ( real )    static permittivity inside the region
    !!      epsilonopt(i) ( real )    optical permittivity inside the region
    !!      x/y/z(i)      ( real )    cartesian center of the region
    !!      width(i)      ( real )    size of the region (in bohr)
    !!      spread(i)     ( real )    spread of the interface (in bohr, optional)
    !!      dim(i)     ( integer )    0/1/2 point/line/plane region (optional)
    !!      axis(i)    ( integer )    1/2/3 for x/y/z direction of line/plane (optional)
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE card_dielectric_regions(unit, input_line)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        INTEGER, INTENT(IN) :: unit
        !
        CHARACTER(LEN=256) :: input_line
        INTEGER :: ie, ix, ierr, nfield
        LOGICAL :: tend
        CHARACTER(LEN=4) :: lb_pos
        CHARACTER(LEN=256) :: field_str
        !
        CHARACTER(LEN=80) :: sub_name = 'card_dielectric_regions'
        !
        !--------------------------------------------------------------------------------
        !
        CALL env_header('Reading DIELECTRIC_REGIONS card')
        !
        !--------------------------------------------------------------------------------
        !
        IF (taepsreg) CALL env_errore(sub_name, 'Two occurrences', 2)
        !
        IF (env_dielectric_regions > nsx) &
            CALL env_errore(sub_name, 'nsx out of range', env_dielectric_regions)
        !
        CALL allocate_input_epsregion(env_dielectric_regions)
        !
        IF (env_is_substring("BOHR", input_line)) THEN
            epsregion_units = 'bohr'
        ELSE IF (env_is_substring("ANGSTROM", input_line)) THEN
            epsregion_units = 'angstrom'
        ELSE
            !
            IF (TRIM(ADJUSTL(input_line)) /= 'DIELECTRIC_REGIONS') &
                CALL env_errore(sub_name, &
                                'Invalid units for DIELECTRIC_REGIONS: '//input_line, 1)
            !
            epsregion_units = 'bohr'
            !
            CALL env_default('region units', epsregion_units, 'default')
            !
        END IF
        !
        !--------------------------------------------------------------------------------
        ! Parse card input
        !
        DO ie = 1, env_dielectric_regions
            !
            CALL env_read_line(unit, input_line, end_of_file=tend)
            !
            IF (tend) &
                CALL env_errore(sub_name, 'End of file reading dielectric regions', ie)
            !
            CALL env_field_count(nfield, input_line)
            !
            !----------------------------------------------------------------------------
            ! Read field 1-2 (static and optical permettivity inside dielectric region)
            !
            CALL env_get_field(1, field_str, input_line)
            !
            READ (field_str, *) epsregion_eps(1, ie)
            !
            IF (epsregion_eps(1, ie) < 1.D0) &
                CALL env_errore(sub_name, 'Static permittivity must be > 1', ie)
            !
            CALL env_get_field(2, field_str, input_line)
            !
            READ (field_str, *) epsregion_eps(2, ie)
            !
            IF (epsregion_eps(2, ie) < 1.D0) &
                CALL env_errore(sub_name, 'Optical permittivity must be > 1', ie)
            !
            !----------------------------------------------------------------------------
            ! Read fields 3-5 (x-y-z position of dielectric region)
            !
            CALL env_get_field(3, field_str, input_line)
            !
            READ (field_str, *) epsregion_pos(1, ie)
            !
            CALL env_get_field(4, field_str, input_line)
            !
            READ (field_str, *) epsregion_pos(2, ie)
            !
            CALL env_get_field(5, field_str, input_line)
            !
            READ (field_str, *) epsregion_pos(3, ie)
            !
            !----------------------------------------------------------------------------
            ! Read field 6 (size/width of the dielectric region)
            !
            CALL env_get_field(6, field_str, input_line)
            !
            READ (field_str, *) epsregion_width(ie)
            !
            IF (epsregion_width(ie) < 0.D0) &
                CALL env_errore(sub_name, 'Width must be positive', ie)
            !
            !----------------------------------------------------------------------------
            ! Optionally read field 7 (spread of interface of the dielectric region)
            !
            IF (nfield >= 7) THEN
                !
                CALL env_get_field(7, field_str, input_line)
                !
                READ (field_str, *) epsregion_spread(ie)
                !
                IF (epsregion_spread(ie) < 0.D0) &
                    CALL env_errore(sub_name, 'Spread must be positive', ie)
                !
            ELSE
                CALL env_default('region spread', '0.5 (a.u.)', 'default')
            END IF
            !
            !----------------------------------------------------------------------------
            ! Optionally read field 8 and 9 (dimensionality and direction)
            !
            IF (nfield >= 8) THEN
                !
                CALL env_get_field(8, field_str, input_line)
                !
                READ (field_str, *) epsregion_dim(ie)
                !
                IF (epsregion_dim(ie) < 0 .OR. epsregion_dim(ie) > 2) &
                    CALL env_errore(sub_name, 'Wrong epsregion dimension', ie)
                !
                IF (epsregion_dim(ie) > 0) THEN
                    !
                    IF (nfield == 8) THEN
                        CALL env_default('axis', '3 (z-axis)', 'default')
                    ELSE
                        !
                        CALL env_get_field(9, field_str, input_line)
                        !
                        READ (field_str, *) epsregion_axis(ie)
                        !
                        IF (epsregion_axis(ie) < 1 .OR. epsregion_axis(ie) > 3) &
                            CALL env_errore(sub_name, 'Wrong epsregion axis', ie)
                        !
                    END IF
                    !
                END IF
                !
            ELSE
                CALL env_default('region dimensions', '0', 'default')
            END IF
            !
        END DO
        !
        !--------------------------------------------------------------------------------
        ! Convert to atomic units
        !
        taepsreg = .TRUE.
        !
        DO ie = 1, env_dielectric_regions
            !
            DO ix = 1, 3
                CALL convert_length(epsregion_units, epsregion_pos(ix, ie))
            END DO
            !
            CALL convert_length(epsregion_units, epsregion_width(ie))
            !
            CALL convert_length(epsregion_units, epsregion_spread(ie))
            !
        END DO
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE card_dielectric_regions
    !------------------------------------------------------------------------------------
    !>
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE allocate_input_epsregion(dielectric_regions)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        INTEGER, INTENT(IN) :: dielectric_regions
        !
        !--------------------------------------------------------------------------------
        !
        IF (ALLOCATED(epsregion_dim)) DEALLOCATE (epsregion_dim)
        !
        IF (ALLOCATED(epsregion_axis)) DEALLOCATE (epsregion_axis)
        !
        IF (ALLOCATED(epsregion_eps)) DEALLOCATE (epsregion_eps)
        !
        IF (ALLOCATED(epsregion_width)) DEALLOCATE (epsregion_width)
        !
        IF (ALLOCATED(epsregion_spread)) DEALLOCATE (epsregion_spread)
        !
        IF (ALLOCATED(epsregion_pos)) DEALLOCATE (epsregion_pos)
        !
        ALLOCATE (epsregion_dim(dielectric_regions))
        ALLOCATE (epsregion_axis(dielectric_regions))
        ALLOCATE (epsregion_eps(2, dielectric_regions))
        ALLOCATE (epsregion_width(dielectric_regions))
        ALLOCATE (epsregion_spread(dielectric_regions))
        ALLOCATE (epsregion_pos(3, dielectric_regions))
        !
        epsregion_dim = 0
        epsregion_axis = 3
        epsregion_eps = 1.0_DP
        epsregion_width = 0.0_DP
        epsregion_spread = 0.5_DP
        epsregion_pos = 0.0_DP
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE allocate_input_epsregion
    !------------------------------------------------------------------------------------
    !>
    !! Convert input length to atomic units
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE convert_length(length_format, length)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        CHARACTER(LEN=*), INTENT(IN) :: length_format
        !
        REAL(DP), INTENT(INOUT) :: length
        !
        CHARACTER(LEN=80) :: sub_name = 'convert_length'
        !
        !--------------------------------------------------------------------------------
        !
        SELECT CASE (length_format)
            !
        CASE ('bohr')
            length = length ! input length are in a.u., do nothing
            !
        CASE ('angstrom')
            length = length / BOHR_RADIUS_ANGS ! length in A: convert to a.u.
            !
        CASE DEFAULT
            CALL env_errore(sub_name, TRIM(length_format)//' units not implemented', 1)
            !
        END SELECT
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE convert_length
    !------------------------------------------------------------------------------------
    !
    !------------------------------------------------------------------------------------
END MODULE environ_input
!----------------------------------------------------------------------------------------
