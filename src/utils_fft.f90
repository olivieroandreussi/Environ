MODULE utils_fft
  !
  USE modules_constants, ONLY : DP, pi, tpi
  USE core_types
  !
  PRIVATE
  !
  PUBLIC :: create_fft_core, init_fft_core_first, init_fft_core_second, &
       update_fft_core_cell, destroy_fft_core, init_dfft, destroy_dfft
  !
CONTAINS
  !--------------------------------------------------------------------
  SUBROUTINE create_fft_core( fft )
!--------------------------------------------------------------------
    !
    IMPLICIT NONE
    !
    TYPE( fft_core ), INTENT(INOUT) :: fft
    !
    ! Create empty fft core
    !
    NULLIFY(fft%dfft)
    NULLIFY(fft%cell)
    !
    RETURN
    !
!--------------------------------------------------------------------
  END SUBROUTINE create_fft_core
!--------------------------------------------------------------------
!--------------------------------------------------------------------
! BACKWARD COMPATIBILITY
! Compatible with QE-6.0 QE-6.1.X QE-6.2.X QE-6.3
!  SUBROUTINE init_fft_core( fft, use_internal_pbc_corr, nspin )
! Compatible with QE-6.4.X QE-GIT
  SUBROUTINE init_fft_core_first( fft, use_internal_pbc_corr )
! END BACKWARD COMPATIBILITY
!--------------------------------------------------------------------
    !
    IMPLICIT NONE
    !
    TYPE( fft_core ), INTENT(INOUT) :: fft
    LOGICAL, INTENT(IN), OPTIONAL :: use_internal_pbc_corr
! BACKWARD COMPATIBILITY
! Compatible with QE-6.0 QE-6.1.X QE-6.2.X QE-6.3.X
!    INTEGER, INTENT(IN), OPTIONAL :: nspin
! Compatible with QE-6.4.X QE-GIT
!
! END BACKWARD COMPATIBILITY
    !
    fft % index = 1
    !
    IF ( PRESENT ( use_internal_pbc_corr ) ) THEN
       fft % use_internal_pbc_corr = use_internal_pbc_corr
    ELSE
       fft % use_internal_pbc_corr = .FALSE.
    END IF
    !
! BACKWARD COMPATIBILITY
! Compatible with QE-6.0 QE-6.1.X QE-6.2.X QE-6.3.X
!    IF ( PRESENT( nspin ) ) THEN
!       fft % nspin = nspin
!    ELSE
!       fft % nspin = 1
!    ENDIF
! Compatible with QE-6.4.X QE-GIT
!
! END BACKWARD COMPATIBILITY
    !
    RETURN
    !
!--------------------------------------------------------------------
  END SUBROUTINE init_fft_core_first
!--------------------------------------------------------------------
!--------------------------------------------------------------------
  SUBROUTINE init_fft_core_second( gcutm, cell, dfft, fft )
!--------------------------------------------------------------------
    !
    USE fft_types,               ONLY : fft_type_init
    USE tools_generate_gvectors, ONLY : env_gvect_init, env_ggen
    USE correction_mt,           ONLY : update_mt_correction
    !
    IMPLICIT NONE
    !
    REAL(DP), INTENT(IN) :: gcutm
    TYPE( environ_cell ), TARGET, INTENT(IN) :: cell
    TYPE( fft_type_descriptor ), TARGET, INTENT(IN) :: dfft
    TYPE( fft_core ), INTENT(INOUT) :: fft
    !
    INTEGER :: ngm_g
    !
    fft%gcutm = gcutm
    fft%cell => cell
    fft%dfft => dfft
    !
    fft%ngm = dfft % ngm
    !
    IF ( fft % use_internal_pbc_corr ) ALLOCATE( fft % mt_corr( fft%ngm ) )
    !
    ! The following routines are in tools_generate_gvect and may need to be simplified
    !
    CALL env_gvect_init( fft, cell%comm )
    CALL env_ggen( fft%dfft, cell%comm, cell%at, cell%bg, fft%gcutm, &
     & ngm_g, fft%ngm, fft%g, fft%gg, fft%gstart, .TRUE. )
    !
    IF ( fft % use_internal_pbc_corr) CALL update_mt_correction( fft )
    !
    RETURN
    !
!--------------------------------------------------------------------
  END SUBROUTINE init_fft_core_second
!--------------------------------------------------------------------
!--------------------------------------------------------------------
  SUBROUTINE update_fft_core_cell( cell, fft )
!--------------------------------------------------------------------
    !
    USE correction_mt, ONLY : update_mt_correction
    !
    IMPLICIT NONE
    !
    TYPE( environ_cell ), TARGET, INTENT(IN) :: cell
    TYPE( fft_core ), INTENT(INOUT) :: fft
    !
    fft % cell => cell
    IF ( fft % use_internal_pbc_corr) CALL update_mt_correction( fft )
    !
    RETURN
    !
!--------------------------------------------------------------------
  END SUBROUTINE update_fft_core_cell
!--------------------------------------------------------------------
!--------------------------------------------------------------------
  SUBROUTINE destroy_fft_core( lflag, fft )
!--------------------------------------------------------------------
    !
    IMPLICIT NONE
    !
    LOGICAL, INTENT(IN) :: lflag
    TYPE( fft_core ), INTENT(INOUT) :: fft
    !
    CHARACTER( LEN = 80 ) :: sub_name = 'destroy_fft_core'
    !
    NULLIFY( fft%dfft )
    NULLIFY( fft%cell )
    DEALLOCATE( fft % gg )
    DEALLOCATE( fft % g )
    IF ( fft % use_internal_pbc_corr ) DEALLOCATE( fft % mt_corr )
    !
    RETURN
    !
!--------------------------------------------------------------------
  END SUBROUTINE destroy_fft_core
!--------------------------------------------------------------------
!--------------------------------------------------------------------
  SUBROUTINE init_dfft( gcutm, comm, at, dfft )
!--------------------------------------------------------------------
    !
    USE stick_base,        ONLY: sticks_map, sticks_map_deallocate
    USE fft_types,         ONLY: fft_type_init
    USE cell_types,        ONLY: recips
    !
    IMPLICIT NONE
    !
    INTEGER, INTENT(IN) :: comm
    REAL(DP), INTENT(IN) :: gcutm, at(3,3)
    TYPE(fft_type_descriptor), INTENT(INOUT) :: dfft
    !
    ! Local Variables
    !
    TYPE( sticks_map ) :: smap
    REAL(DP), DIMENSION(3,3) :: bg
    !
    ! Calculate the reciprocal lattice vectors
    !
    CALL recips( at(1,1), at(1,2), at(1,3), bg(1,1), &
      & bg(1,2), bg(1,3))
    !
    CALL fft_type_init( dfft, smap, "rho", .TRUE., .TRUE., comm, at, &
         & bg, gcutm, nyfft=1 )
    dfft%rho_clock_label='fft'
    !
    CALL sticks_map_deallocate( smap )
    !
    RETURN
    !
!--------------------------------------------------------------------
  END SUBROUTINE init_dfft
!--------------------------------------------------------------------
!--------------------------------------------------------------------
  SUBROUTINE destroy_dfft( lflag, dfft )
!--------------------------------------------------------------------
    !
    USE fft_types,         ONLY: fft_type_deallocate
    !
    IMPLICIT NONE
    !
    LOGICAL, INTENT(IN) :: lflag
    TYPE(fft_type_descriptor), INTENT(INOUT) :: dfft
    !
    CALL fft_type_deallocate( dfft )
    !
    RETURN
    !
!--------------------------------------------------------------------
  END SUBROUTINE destroy_dfft
!--------------------------------------------------------------------
END MODULE utils_fft
