! Copyright (C) 2018 ENVIRON (www.quantum-environment.org)
! Copyright (C) 2006-2010 Quantum ESPRESSO group
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
!> Module containing the main drivers to compute Environ contributions
!! to Kohn-Sham potential, total energy and inter-atomic forces
!
! Authors: Oliviero Andreussi (Department of Physics, UNT)
!          Francesco Nattino  (THEOS and NCCR-MARVEL, EPFL)
!          Ismaila Dabo       (DMSE, Penn State)
!          Nicola Marzari     (THEOS and NCCR-MARVEL, EPFL)
!
!----------------------------------------------------------------------------
MODULE environ_main
!----------------------------------------------------------------------------
  !
  USE environ_types
  USE electrostatic_types
  USE environ_output
  !
PRIVATE
!
PUBLIC :: calc_venviron, calc_eenviron, calc_fenviron, calc_dvenviron
!
CONTAINS
!  Subroutine: calc_venviron
!
!> Calculates the Environ contribution to the local potential. All
!! the Environ modules need to be called here. The potentials are
!! all computed on the dense real-space grid and added to vtot.
!--------------------------------------------------------------------
  SUBROUTINE calc_venviron( update, nnr, vtot, local_verbose )
!--------------------------------------------------------------------
    USE environ_base,  ONLY : vzero, solvent,                       &
                              lelectrostatic, velectrostatic,       &
                              vreference, dvtot,                    &
                              lsoftcavity, vsoftcavity,             &
                              lsurface, env_surface_tension,        &
                              lvolume, env_pressure,                &
                              lconfine, env_confine, vconfine,      &
                              lstatic, static, lexternals,          &
                              lelectrolyte, electrolyte,            &
                              lsoftsolvent, lsoftelectrolyte,       &
                              system_cell, environment_cell,        &
                              system_charges, environment_charges,  &
                              mapping
    USE electrostatic_base, ONLY : reference, outer
    !
    ! ... Each contribution to the potential is computed in its module
    !
    USE embedding_electrostatic, ONLY : calc_velectrostatic
    USE embedding_surface,       ONLY : calc_desurface_dboundary
    USE embedding_volume,        ONLY : calc_devolume_dboundary
    USE embedding_confine,       ONLY : calc_vconfine, &
                                        calc_deconfine_dboundary
    USE utils_dielectric,        ONLY : calc_dedielectric_dboundary
    USE utils_electrolyte,       ONLY : calc_deelectrolyte_dboundary
    USE utils_charges,           ONLY : update_environ_charges, &
                                      & charges_of_potential
    USE utils_mapping,           ONLY : map_large_to_small, map_small_to_large
    USE tools_generate_boundary, ONLY : solvent_aware_de_dboundary, &
                                      & field_aware_de_drho
    !
    IMPLICIT NONE
    !
    ! ... Declares variables
    !
    LOGICAL, INTENT(IN)       :: update
    INTEGER, INTENT(IN)       :: nnr
    REAL( DP ), INTENT(OUT)   :: vtot( nnr )
    INTEGER, INTENT(IN), OPTIONAL :: local_verbose
    !
    TYPE( environ_density ) :: aux
    TYPE( environ_density ) :: de_dboundary
    !
    ! ... If not updating the potentials, add old potentials and exit
    !
    vtot = vzero % of_r
    !
    IF ( .NOT. update ) THEN
       !
       vtot = vtot + dvtot % of_r
       !
       IF ( PRESENT( local_verbose ) ) THEN
          !
          CALL print_environ_density( dvtot, local_verbose )
          IF ( lelectrostatic ) CALL print_environ_density( vreference, local_verbose )
          IF ( lelectrostatic ) CALL print_environ_density( velectrostatic, local_verbose )
          IF ( lelectrostatic ) CALL print_environ_charges( system_charges, local_verbose, local_depth=0 )
          IF ( lconfine ) CALL print_environ_density( vconfine, local_verbose )
          IF ( lsoftcavity ) CALL print_environ_density( vsoftcavity, local_verbose )
          !
       END IF
       !
       RETURN
       !
    END IF
    !
    dvtot % of_r = 0.D0
    CALL init_environ_density( system_cell, aux )
    !
    ! ... If any form of electrostatic embedding is present, calculate its contribution
    !
    IF ( lelectrostatic ) THEN
       !
       ! ... Electrostatics is also computed inside the calling program, need to remove the reference
       !
       CALL calc_velectrostatic( reference, system_charges, vreference )
       CALL print_environ_density( vreference )
       !
       CALL calc_velectrostatic( outer, environment_charges, velectrostatic )
       !IF ( lexternals ) CALL update_environ_charges( environment_charges, lexternals )
       !
       CALL print_environ_density( velectrostatic )
       !
       CALL map_large_to_small( mapping, velectrostatic, aux )
       dvtot % of_r = aux % of_r - vreference % of_r
       !
       CALL charges_of_potential( velectrostatic, environment_charges )
       CALL print_environ_charges( environment_charges )
       !
    END IF
    !
    IF ( lconfine ) THEN
       !
       CALL calc_vconfine( env_confine, solvent, vconfine )
       CALL print_environ_density( vconfine )
       !
       CALL map_large_to_small( mapping, vconfine, aux )
       dvtot % of_r = dvtot % of_r + aux % of_r
       !
    END IF
    !
    ! ... Compute the total potential depending on the boundary !!!! NEEDS TO BE FIXED
    !
    IF ( lsoftcavity ) THEN
       !
       vsoftcavity % of_r = 0.D0
       CALL init_environ_density( environment_cell, de_dboundary )
       !
       IF ( lsoftsolvent ) THEN
          !
          de_dboundary % of_r = 0.D0
          !
          ! ... If surface tension greater than zero, calculates cavity contribution
          !
          IF ( lsurface ) CALL calc_desurface_dboundary( env_surface_tension, solvent, de_dboundary )
          !
          ! ... If external pressure different from zero, calculates PV contribution
          !
          IF ( lvolume ) CALL calc_devolume_dboundary( env_pressure, solvent, de_dboundary )
          !
          ! ... If confinement potential different from zero, calculates confine contribution
          !
          IF ( lconfine ) CALL calc_deconfine_dboundary( env_confine, environment_charges%electrons%density, de_dboundary )
          !
          ! ... If dielectric embedding, calcultes dielectric contribution
          !
          IF ( lstatic ) CALL calc_dedielectric_dboundary( static, velectrostatic, de_dboundary )
          !
          ! ... If solvent-aware interface correct the potential
          !
          IF ( solvent % solvent_aware ) CALL solvent_aware_de_dboundary( solvent, de_dboundary )
          !
          IF ( solvent % field_aware ) THEN
             !
             ! ... If field-aware interface use a more cumbersome formula
             !
             !CALL field_aware_de_drho( solvent, de_dboundary, vsoftcavity )
             CALL errore( 'field-aware1', 'Option not yet implimented ', 1 )
             !
          ELSE
             !
             ! ... Otherwiese, multiply for the derivative of the boundary wrt electronic density
             !
             vsoftcavity % of_r = de_dboundary % of_r * solvent % dscaled % of_r
             !
          ENDIF
          !
       END IF
       !
       IF ( lsoftelectrolyte ) THEN
          !
          de_dboundary % of_r = 0.D0
          !
          ! ... If electrolyte is present add its non-electrostatic contribution
          !
          CALL calc_deelectrolyte_dboundary( electrolyte, de_dboundary )
          !
          ! ... If solvent-aware interface correct the potential
          !
          IF ( electrolyte % boundary % solvent_aware ) CALL solvent_aware_de_dboundary( electrolyte % boundary, de_dboundary )
          !
          IF ( electrolyte % boundary % field_aware ) THEN
             !
             ! ... If field-aware interface correct the derivative of the interface function
             !
             !CALL field_aware_de_drho( electrolyte % boundary, de_dboundary, vsoftcavity )
             CALL errore( 'field-aware2', 'Option not yet implimented ', 1 )
             !
          ELSE
             !
             ! ... Multiply for the derivative of the boundary wrt electronic density
             !
             vsoftcavity % of_r = vsoftcavity % of_r + de_dboundary % of_r * electrolyte % boundary % dscaled % of_r
             !
          ENDIF
          !
       END IF
       !
       CALL print_environ_density( vsoftcavity )
       CALL map_large_to_small( mapping, vsoftcavity, aux )
       dvtot % of_r = dvtot % of_r + aux % of_r
       !
       CALL destroy_environ_density( de_dboundary )
       !
    END IF
    !
    CALL destroy_environ_density( aux )
    CALL print_environ_density( dvtot, local_verbose )
    !
    vtot = vtot + dvtot % of_r
    !
    RETURN
!--------------------------------------------------------------------
  END SUBROUTINE calc_venviron
!--------------------------------------------------------------------
!  Subroutine: calc_eenviron
!
!> Calculates the Environ contribution to the energy. We must remove
!! int v_environ * rhoelec that is automatically included in the
!! energy computed as the sum of Kohn-Sham eigenvalues.
!--------------------------------------------------------------------
  SUBROUTINE calc_eenviron( deenviron, eelectrostatic, esurface, &
       & evolume, econfine, eelectrolyte )
!--------------------------------------------------------------------
    USE environ_base,  ONLY : system_electrons, solvent,            &
                              lelectrostatic, velectrostatic,       &
                              vreference, dvtot,                    &
                              lsoftcavity, vsoftcavity,             &
                              lsurface, env_surface_tension,        &
                              lvolume, env_pressure,                &
                              lconfine, vconfine, env_confine,      &
                              lstatic, static,                      &
                              lelectrolyte, electrolyte,            &
                              system_charges, environment_charges,  &
                              environment_electrons, niter
    USE electrostatic_base, ONLY : reference, outer
    !
    ! ... Each contribution to the energy is computed in its module
    !
    USE embedding_electrostatic, ONLY : calc_eelectrostatic
    USE embedding_surface,       ONLY : calc_esurface
    USE embedding_volume,        ONLY : calc_evolume
!    USE embedding_confine,       ONLY : calc_econfine
    USE utils_electrolyte,       ONLY : calc_eelectrolyte
    USE utils_charges,           ONLY : update_environ_charges
    !
    IMPLICIT NONE
    !
    ! ... Declares variables
    !
    REAL( DP ), INTENT(OUT) :: deenviron, eelectrostatic, esurface, &
         evolume, econfine, eelectrolyte
    REAL( DP ) :: ereference
    !
    ! ... Initializes the variables
    !
    eelectrostatic = 0.D0
    esurface       = 0.D0
    evolume        = 0.D0
    econfine       = 0.D0
    eelectrolyte   = 0.D0
    !
    niter = niter + 1
    !
    ! ... Calculates the energy corrections
    !
    deenviron = - scalar_product_environ_density( system_electrons%density, dvtot )
    !
    ! if electrostatic is on compute electrostatic energy
    !
    IF ( lelectrostatic ) THEN
       !
       !
       CALL calc_eelectrostatic( reference%core, system_charges, vreference, ereference )
       !
       CALL calc_eelectrostatic( outer%core, environment_charges, velectrostatic, eelectrostatic )
       !
       eelectrostatic = eelectrostatic - ereference
       !
    END IF
    !
    !  if surface tension different from zero compute cavitation energy
    !
    IF ( lsurface ) CALL calc_esurface( env_surface_tension, solvent, esurface )
    !
    !  if pressure different from zero compute PV energy
    !
    IF ( lvolume ) CALL calc_evolume( env_pressure, solvent, evolume )
    !
    !  if confinement potential different from zero compute confine energy
    !
    IF ( lconfine ) econfine = scalar_product_environ_density( environment_electrons%density, vconfine )
    !
    !  if electrolyte is present calculate its non-electrostatic contribution
    !
    IF ( lelectrolyte ) CALL calc_eelectrolyte( electrolyte, eelectrolyte )
    !
    RETURN
    !
!--------------------------------------------------------------------
  END SUBROUTINE calc_eenviron
!--------------------------------------------------------------------
!  Subroutine: calc_fenviron
!
!> Calculates the Environ contribution to the forces. Due to
!! Hellman-Feynman only a few of the Environ modules have an
!! effect on the atomic forces.
!--------------------------------------------------------------------
  SUBROUTINE calc_fenviron( nat, force_environ )
!--------------------------------------------------------------------
    USE environ_base, ONLY : lelectrostatic, velectrostatic,    &
                             lstatic, static,                   &
                             lelectrolyte, electrolyte,         &
                             lrigidcavity, lrigidsolvent,       &
                             lrigidelectrolyte,                 &
                             lsurface, env_surface_tension,     &
                             lvolume, env_pressure,             &
                             lconfine, env_confine,             &
                             lsolvent, solvent, system_cell,    &
                             environment_cell, system_charges,  &
                             environment_charges
    !
    USE electrostatic_base, ONLY : outer
    !
    ! ... Each contribution to the forces is computed in its module
    !
    USE embedding_electrostatic, ONLY : calc_felectrostatic
    USE embedding_surface,       ONLY : calc_desurface_dboundary
    USE embedding_volume,        ONLY : calc_devolume_dboundary
    USE embedding_confine,       ONLY : calc_deconfine_dboundary
    USE utils_dielectric,        ONLY : calc_dedielectric_dboundary
    USE utils_electrolyte,       ONLY : calc_deelectrolyte_dboundary
    USE tools_generate_boundary, ONLY : calc_dboundary_dions, solvent_aware_de_dboundary, &
         & field_aware_dboundary_dions, compute_ion_field_partial
    !
    IMPLICIT NONE
    !
    INTEGER, INTENT(IN) :: nat
    REAL( DP ), INTENT(INOUT) :: force_environ( 3, nat )
    !
    INTEGER :: i
    TYPE( environ_density ) :: de_dboundary
    TYPE( environ_gradient ) :: partial
    !
    force_environ = 0.D0
    !
    IF ( lelectrostatic ) CALL calc_felectrostatic( outer, nat, environment_charges, force_environ )
    !
    ! ... Compute the total forces depending on the boundary
    !
    IF ( lrigidcavity ) THEN
       !
       CALL init_environ_density( environment_cell, de_dboundary )
       !
       CALL init_environ_gradient( environment_cell, partial )
       !
       IF ( lrigidsolvent ) THEN !!! NEEDS TO BE FIXED
          !
          de_dboundary % of_r = 0.D0
          !
          ! ... If surface tension greater than zero, calculates cavity contribution
          !
          IF ( lsurface ) CALL calc_desurface_dboundary( env_surface_tension, solvent, de_dboundary )
          !
          ! ... If external pressure different from zero, calculates PV contribution
          !
          IF ( lvolume ) CALL calc_devolume_dboundary( env_pressure, solvent, de_dboundary )
          !
          ! ... If confinement potential different from zero, calculates confine contribution
          !
          IF ( lconfine ) CALL calc_deconfine_dboundary( env_confine, environment_charges%electrons%density, de_dboundary )
          !
          ! ... If dielectric embedding, calcultes dielectric contribution
          !
          IF ( lstatic ) CALL calc_dedielectric_dboundary( static, velectrostatic, de_dboundary )
          !
          ! ... If solvent-aware interface correct the potential
          !
          IF ( solvent % solvent_aware ) CALL solvent_aware_de_dboundary( solvent, de_dboundary )
          !
          ! ... If field-aware compute partial derivatives of field fluxes wrt ionic positions
          !
          !IF ( solvent % mode .EQ. 'fa-ionic' ) CALL compute_ion_field_partial( solvent%ions%number, solvent%soft_spheres, &
          !     & solvent%ions, solvent%electrons, solvent%ion_field, solvent%partial_of_ion_field, solvent % core % fft )
          !
          ! ... Multiply for the derivative of the boundary wrt ionic positions
          !
          DO i = 1, nat
             !
             CALL calc_dboundary_dions( i, solvent, partial )
             !
             ! ... If field-aware interface correct the derivative of the interface function
             !
             !IF ( solvent % field_aware ) CALL field_aware_dboundary_dions( i, solvent, partial )
             !
             force_environ( :, i ) = force_environ( :, i ) &
                  & - scalar_product_environ_gradient_density( partial, de_dboundary )
             !
          END DO
          !
       END IF
       !
       IF ( lrigidelectrolyte ) THEN
          !
          de_dboundary % of_r = 0.D0
          !
          ! ... If electrolyte is present, add its non-electrostatic contribution
          !
          CALL calc_deelectrolyte_dboundary( electrolyte, de_dboundary )
          !
          ! ... If solvent-aware interface correct the potential
          !
          IF ( electrolyte % boundary % solvent_aware ) CALL solvent_aware_de_dboundary( electrolyte % boundary, de_dboundary )
          !
          ! ... If field-aware compute partial derivatives of field fluxes wrt ionic positions
          !
          !IF ( electrolyte % boundary % mode .EQ. 'fa-ionic' ) CALL !compute_ion_field_partial( electrolyte%boundary%ions%number, &
          !     & electrolyte%boundary%soft_spheres, electrolyte%boundary%ions, !electrolyte%boundary%electrons, &
          !     & electrolyte%boundary%ion_field, !electrolyte%boundary%partial_of_ion_field, electrolyte%boundary%core%fft )
          !
          ! ... Multiply for the derivative of the boundary wrt ionic positions
          !
          DO i = 1, nat
             !
             CALL calc_dboundary_dions( i, electrolyte % boundary, partial )
             !
             ! ... If field-aware interface correct the derivative of the interface function
             !
             !IF ( electrolyte % boundary % field_aware ) CALL field_aware_dboundary_dions( i, electrolyte % boundary, partial )
             !
             force_environ( :, i ) = force_environ( :, i ) &
                  & - scalar_product_environ_gradient_density( partial, de_dboundary )
             !
          END DO
          !
       END IF
       !
       CALL destroy_environ_gradient( partial )
       !
       CALL destroy_environ_density( de_dboundary )
       !
    END IF
    !
    RETURN
    !
!--------------------------------------------------------------------
  END SUBROUTINE calc_fenviron
!--------------------------------------------------------------------
!  Subroutine: calc_denviron
!
!> Calculates the Environ contribution to the local potential. All
!! the Environ modules need to be called here. The potentials are
!! all computed on the dense real-space grid and added to vtot.
!--------------------------------------------------------------------
  SUBROUTINE calc_dvenviron( nnr, rho, drho, dvtot )
!--------------------------------------------------------------------
    USE environ_base,  ONLY : vzero, solvent,                       &
                              lelectrostatic, loptical
    !
    ! ... Each contribution to the potential is computed in its module
    !
    USE solvent_tddfpt, ONLY : calc_vsolvent_tddfpt
    !
    IMPLICIT NONE
    !
    ! ... Declares variables
    !
    INTEGER, INTENT(IN)     :: nnr
    REAL( DP ), INTENT(IN)  :: rho( nnr )    !> ground-state charge-density
    REAL( DP ), INTENT(IN)  :: drho( nnr )   !> response charge-density
    REAL( DP ), INTENT(OUT) :: dvtot( nnr )
    !
    ! ... Local variables
    !
    REAL( DP ), DIMENSION( : ), ALLOCATABLE :: dvpol, dvepsilon
    !
    ! ... If any form of electrostatic embedding is present, calculate its contribution
    !
    IF ( lelectrostatic ) THEN
       !
       ! ... Electrostatics is also computed inside the calling program, need to remove the reference
       !
       IF ( loptical ) THEN
          !
          ALLOCATE( dvpol( nnr ) )
          dvpol = 0.D0
          ALLOCATE( dvepsilon( nnr ) )
          dvepsilon = 0.D0
          !
! BACKWARD COMPATIBILITY
! Compatible with QE-6.0 QE-6.1.X QE-6.2.X QE-6.3.X
!          CALL calc_vsolvent_tddfpt(nnr, 1, rho, drho, dvpol, dvepsilon)
! Compatible with QE-6.4.X QE-GIT
          CALL calc_vsolvent_tddfpt(nnr, rho, drho, dvpol, dvepsilon)
! END BACKWARD COMPATIBILITY
          !
          dvtot = dvtot + dvpol + dvepsilon
          !
          DEALLOCATE( dvpol )
          DEALLOCATE( dvepsilon )
          !
       ENDIF
       !
    END IF
    !
    RETURN
!--------------------------------------------------------------------
  END SUBROUTINE calc_dvenviron
!--------------------------------------------------------------------
!----------------------------------------------------------------------------
END MODULE environ_main
!----------------------------------------------------------------------------
