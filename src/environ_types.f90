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
! Authors: Oliviero Andreussi (Department of Physics, UNT)
!          Francesco Nattino  (THEOS and NCCR-MARVEL, EPFL)
!          Nicola Marzari     (THEOS and NCCR-MARVEL, EPFL)
!
!----------------------------------------------------------------------------------------
!>
!! This module contains the main control and parameter variables from QE Modules,
!! the definitions of Environ derived data types and the routines to handle the
!! basic derived data types (cell, density, gradient, hessian, electrons, system)
!!
!----------------------------------------------------------------------------------------
MODULE environ_types
    !------------------------------------------------------------------------------------
    !
    USE cell_types
    USE core_types
    USE modules_constants, ONLY: DP
    USE mp, ONLY: mp_sum
    ! BACKWARD COMPATIBILITY
    ! Compatible with QE-5.X QE-6.1.X QE-6.2.X
    ! USE control_flags, ONLY: tddfpt
    ! Compatible with QE-6.3.X and QE-GIT \
    ! END BACKWARD COMPATIBILITY
    !------------------------------------------------------------------------------------
    !>
    !!
    !------------------------------------------------------------------------------------
    TYPE environ_density
        !--------------------------------------------------------------------------------
        !
        LOGICAL :: update = .FALSE. ! optionally have an associated logical status
        !
        CHARACTER(LEN=80) :: label = ' '
        ! optionally have an associated label, used for printout and debugs
        !
        TYPE(environ_cell), POINTER :: cell => NULL()
        ! each quantity in real-space is associated with its definition domain
        !
        REAL(DP), ALLOCATABLE :: of_r(:)
        ! the quantity in real-space, local to each processor
        !
        !--------------------------------------------------------------------------------
        ! Multipole moments of the quantity
        !
        REAL(DP) :: charge
        REAL(DP) :: dipole(3)
        REAL(DP) :: quadrupole(3)
        !
        !--------------------------------------------------------------------------------
    END TYPE environ_density
    !------------------------------------------------------------------------------------
    !>
    !!
    !------------------------------------------------------------------------------------
    TYPE environ_gradient
        !--------------------------------------------------------------------------------
        !
        LOGICAL :: update = .FALSE. ! optionally have an associated logical status
        !
        CHARACTER(LEN=80) :: label = ' '
        ! optionally have an associated label, used for printout and debugs
        !
        TYPE(environ_cell), POINTER :: cell => NULL()
        ! each quantity in real-space is associated with its definition domain
        !
        REAL(DP), ALLOCATABLE :: of_r(:, :)
        ! the quantity in real-space, local to each processor
        !
        TYPE(environ_density) :: modulus
        !
        !--------------------------------------------------------------------------------
    END TYPE environ_gradient
    !------------------------------------------------------------------------------------
    !>
    !!
    !------------------------------------------------------------------------------------
    TYPE environ_hessian
        !--------------------------------------------------------------------------------
        !
        LOGICAL :: update = .FALSE. ! optionally have an associated logical status
        !
        CHARACTER(LEN=80) :: label = ' '
        ! optionally have an associated label, used for printout and debugs
        !
        TYPE(environ_cell), POINTER :: cell => NULL()
        ! each quantity in real-space is associated with its definition domain
        !
        REAL(DP), ALLOCATABLE :: of_r(:, :, :)
        ! the quantity in real-space, local to each processor
        !
        TYPE(environ_density) :: laplacian
        !
        !--------------------------------------------------------------------------------
    END TYPE environ_hessian
    !------------------------------------------------------------------------------------
    !>
    !!
    !------------------------------------------------------------------------------------
    TYPE environ_functions
        !--------------------------------------------------------------------------------
        !
        INTEGER :: type_
        INTEGER :: axis, dim
        REAL(DP) :: width, spread, volume
        REAL(DP), POINTER :: pos(:)
        ! environ_functions are not designed to be mobile, thus position
        ! can be included in the definition of the type
        !
        !--------------------------------------------------------------------------------
    END TYPE environ_functions
    !------------------------------------------------------------------------------------
    !>
    !!
    !------------------------------------------------------------------------------------
    TYPE environ_iontype
        !--------------------------------------------------------------------------------
        !
        INTEGER :: index
        INTEGER :: atmnum
        CHARACTER(LEN=3) :: label
        REAL(DP) :: zv
        REAL(DP) :: atomicspread
        REAL(DP) :: corespread
        REAL(DP) :: solvationrad
        !
        !--------------------------------------------------------------------------------
    END TYPE environ_iontype
    !------------------------------------------------------------------------------------
    !>
    !!
    !------------------------------------------------------------------------------------
    TYPE environ_ions
        !--------------------------------------------------------------------------------
        !
        LOGICAL :: initialized = .FALSE.
        LOGICAL :: update = .FALSE.
        INTEGER :: number = 0
        REAL(DP) :: center(3)
        REAL(DP) :: alat
        !
        !--------------------------------------------------------------------------------
        ! Specifications of point-like ions
        !
        INTEGER :: ntyp = 0
        INTEGER, ALLOCATABLE :: ityp(:)
        REAL(DP), POINTER :: tau(:, :)
        TYPE(environ_iontype), ALLOCATABLE :: iontype(:)
        !
        !--------------------------------------------------------------------------------
        ! Parameters of the fictitious gaussian ionic density
        ! needed by electrostatic calculations
        !
        LOGICAL :: use_smeared_ions = .FALSE.
        TYPE(environ_functions), ALLOCATABLE :: smeared_ions(:)
        TYPE(environ_density) :: density
        !
        !--------------------------------------------------------------------------------
        ! Parameters of the density of core electrons
        !
        LOGICAL :: use_core_electrons = .FALSE.
        TYPE(environ_functions), ALLOCATABLE :: core_electrons(:)
        TYPE(environ_density) :: core
        TYPE(environ_density), ALLOCATABLE :: vloc(:)
        !
        REAL(DP) :: charge = 0.0_DP
        REAL(DP) :: quadrupole_correction
        REAL(DP) :: selfenergy_correction
        REAL(DP) :: dipole(3)
        REAL(DP) :: quadrupole_pc(3)
        REAL(DP) :: quadrupole_gauss(3)
        !
        !--------------------------------------------------------------------------------
    END TYPE environ_ions
    !------------------------------------------------------------------------------------
    !>
    !!
    !------------------------------------------------------------------------------------
    TYPE environ_electrons
        !--------------------------------------------------------------------------------
        !
        LOGICAL :: update = .FALSE.
        LOGICAL :: initialized = .FALSE.
        INTEGER :: number = 0
        ! BACKWARD COMPATIBILITY
        ! Compatible with QE-6.0 QE-6.1.X QE-6.2.X QE-6.3.X
        ! INTEGER :: nspin = 1
        ! Compatible with QE-6.4.X QE-GIT
        !
        ! END BACKWARD COMPATIBILITY
        !
        TYPE(environ_density) :: density
        REAL(DP) :: charge = 0.0_DP
        !
        !--------------------------------------------------------------------------------
    END TYPE environ_electrons
    !------------------------------------------------------------------------------------
    !>
    !!
    !------------------------------------------------------------------------------------
    TYPE environ_externals
        !--------------------------------------------------------------------------------
        !
        LOGICAL :: update = .FALSE.
        LOGICAL :: initialized = .FALSE.
        INTEGER :: number = 0
        !
        TYPE(environ_functions), ALLOCATABLE :: functions(:)
        TYPE(environ_density) :: density
        REAL(DP) :: charge = 0.0_DP
        !
        !--------------------------------------------------------------------------------
    END TYPE environ_externals
    !------------------------------------------------------------------------------------
    !>
    !!
    !------------------------------------------------------------------------------------
    TYPE environ_charges
        !--------------------------------------------------------------------------------
        !
        LOGICAL :: include_ions = .FALSE.
        TYPE(environ_ions), POINTER :: ions => NULL()
        !
        LOGICAL :: include_electrons = .FALSE.
        TYPE(environ_electrons), POINTER :: electrons => NULL()
        !
        LOGICAL :: include_externals = .FALSE.
        TYPE(environ_externals), POINTER :: externals => NULL()
        !
        LOGICAL :: include_dielectric = .FALSE.
        TYPE(environ_dielectric), POINTER :: dielectric => NULL()
        !
        LOGICAL :: include_electrolyte = .FALSE.
        TYPE(environ_electrolyte), POINTER :: electrolyte => NULL()
        !
        LOGICAL :: include_semiconductor = .FALSE.
        TYPE(environ_semiconductor), POINTER :: semiconductor => NULL()
        !
        !--------------------------------------------------------------------------------
        ! Total smooth free charge
        !
        INTEGER :: number = 0
        REAL(DP) :: charge = 0.0_DP
        TYPE(environ_density) :: density
        LOGICAL :: initialized = .FALSE.
        !
        !--------------------------------------------------------------------------------
    END TYPE environ_charges
    !------------------------------------------------------------------------------------
    !>
    !!
    !------------------------------------------------------------------------------------
    TYPE environ_system
        !--------------------------------------------------------------------------------
        !
        LOGICAL :: update = .FALSE.
        INTEGER :: ntyp
        INTEGER :: dim
        INTEGER :: axis
        REAL(DP) :: pos(3)
        REAL(DP) :: width
        !
        TYPE(environ_ions), POINTER :: ions
        !
        !--------------------------------------------------------------------------------
    END TYPE environ_system
    !------------------------------------------------------------------------------------
    !>
    !!
    !------------------------------------------------------------------------------------
    TYPE boundary_core
        !--------------------------------------------------------------------------------
        !
        CHARACTER(LEN=80) :: type_
        !
        LOGICAL :: use_fft
        TYPE(fft_core), POINTER :: fft => NULL() ! #TODO if testing freaks out, comment out nullification
        !
        LOGICAL :: use_fd
        TYPE(fd_core), POINTER :: fd => NULL()
        !
        !--------------------------------------------------------------------------------
    END TYPE boundary_core
    !------------------------------------------------------------------------------------
    !>
    !! #TODO: update utils_boundary.f90 when settled on variable name
    !!
    !------------------------------------------------------------------------------------
    TYPE environ_boundary
        !--------------------------------------------------------------------------------
        !
        CHARACTER(LEN=80) :: label ! Boundary label
        CHARACTER(LEN=80) :: mode ! Choice of the interface
        INTEGER :: update_status = 0
        LOGICAL :: initialized = .FALSE.
        !
        !--------------------------------------------------------------------------------
        ! Parameters for the electrons-dependent interface
        !
        LOGICAL :: need_electrons
        TYPE(environ_electrons), POINTER :: electrons
        !
        !--------------------------------------------------------------------------------
        ! Parameters for the ions-dependent interface
        !
        LOGICAL :: need_ions
        TYPE(environ_ions), POINTER :: ions
        !
        !--------------------------------------------------------------------------------
        ! Parameters for the system-dependent interface
        !
        LOGICAL :: need_system
        TYPE(environ_system), POINTER :: system
        !
        !--------------------------------------------------------------------------------
        ! #TODO change scaled to interface
        TYPE(environ_density) :: scaled ! scaled switching function of interface
        ! varying from 1 (QM region) to 0 (environment region)
        !
        INTEGER :: deriv = 0
        TYPE(environ_gradient) :: gradient
        TYPE(environ_density) :: laplacian
        TYPE(environ_density) :: dsurface
        TYPE(environ_hessian) :: hessian
        !
        TYPE(boundary_core), POINTER :: core
        !
        !--------------------------------------------------------------------------------
        ! Global properties of the boundary
        !
        REAL(DP) :: volume
        REAL(DP) :: surface
        !
        !--------------------------------------------------------------------------------
        ! Components needed for boundary of density
        !
        INTEGER :: type_
        REAL(DP) :: rhomax, rhomin, fact
        REAL(DP) :: rhozero, deltarho, tbeta
        REAL(DP) :: const
        TYPE(environ_density) :: density
        !
        TYPE(environ_density) :: dscaled ! #TODO dinterface
        TYPE(environ_density) :: d2scaled
        !
        !--------------------------------------------------------------------------------
        ! Components needed for boundary of functions
        !
        REAL(DP) :: alpha ! solvent-dependent scaling factor
        REAL(DP) :: softness ! sharpness of the interface
        TYPE(environ_functions), ALLOCATABLE :: soft_spheres(:)
        !
        !--------------------------------------------------------------------------------
        !
        TYPE(environ_functions) :: simple ! Components needed for boundary of system
        !
        !--------------------------------------------------------------------------------
        ! Components needed for solvent-aware boundary
        !
        LOGICAL :: solvent_aware
        TYPE(environ_functions) :: solvent_probe
        REAL(DP) :: filling_threshold, filling_spread
        !
        TYPE(environ_density) :: local
        TYPE(environ_density) :: probe
        TYPE(environ_density) :: filling
        TYPE(environ_density) :: dfilling
        !
        !--------------------------------------------------------------------------------
        ! Components needed for field-aware boundary
        !
        LOGICAL :: field_aware
        REAL(DP) :: field_factor, charge_asymmetry, field_max, field_min
        !
        TYPE(environ_density) :: normal_field
        REAL(DP), ALLOCATABLE :: ion_field(:)
        TYPE(environ_functions), ALLOCATABLE :: local_spheres(:)
        TYPE(environ_density), ALLOCATABLE :: dion_field_drho(:)
        REAL(DP), ALLOCATABLE :: partial_of_ion_field(:, :, :)
        !
        !--------------------------------------------------------------------------------
    END TYPE environ_boundary
    !------------------------------------------------------------------------------------
    !>
    !!
    !------------------------------------------------------------------------------------
    TYPE environ_dielectric
        !--------------------------------------------------------------------------------
        !
        LOGICAL :: update = .FALSE.
        LOGICAL :: initialized = .FALSE.
        !
        !--------------------------------------------------------------------------------
        ! Basic properties of the dielectric space from input
        !
        INTEGER :: nregions
        TYPE(environ_functions), ALLOCATABLE :: regions(:)
        !
        REAL(DP) :: constant
        TYPE(environ_density) :: background
        TYPE(environ_gradient) :: gradbackground
        TYPE(environ_density) :: laplbackground
        !
        !--------------------------------------------------------------------------------
        !
        TYPE(environ_boundary), POINTER :: boundary
        ! boundary is the pointer to the object controlling the interface
        ! between the QM and the continuum region
        !
        !--------------------------------------------------------------------------------
        ! The dielectric function over space is built from the boundary of the
        ! continuum environment and the basic dielectric properties of space
        !
        TYPE(environ_density) :: epsilon
        !
        TYPE(environ_density) :: depsilon
        ! this is needed in the extra term of kohn-sham/forces
        !
        !--------------------------------------------------------------------------------
        ! Quantities related to the dielectric permittivity and
        ! they may be needed by the different solvers
        !
        LOGICAL :: need_gradient = .FALSE.
        TYPE(environ_gradient) :: gradient
        !
        LOGICAL :: need_factsqrt = .FALSE.
        TYPE(environ_density) :: factsqrt
        !
        LOGICAL :: need_gradlog = .FALSE.
        TYPE(environ_gradient) :: gradlog
        !
        !--------------------------------------------------------------------------------
        ! Dielectric polarization charges and individual components
        !
        TYPE(environ_density) :: density
        LOGICAL :: need_auxiliary = .FALSE.
        TYPE(environ_density) :: iterative
        REAL(DP) :: charge = 0.0_DP
        !
        !--------------------------------------------------------------------------------
    END TYPE environ_dielectric
    !------------------------------------------------------------------------------------
    !>
    !!
    !------------------------------------------------------------------------------------
    TYPE environ_ioncctype
        !--------------------------------------------------------------------------------
        !
        INTEGER :: index
        REAL(DP) :: cbulk ! bulk concentration
        REAL(DP) :: z ! charge
        !
        TYPE(environ_density) :: c ! local concentration
        TYPE(environ_density) :: cfactor ! exp(-z\phi\beta) or 1 - z\phi\beta
        TYPE(environ_density) :: potential
        !
        !--------------------------------------------------------------------------------
    END TYPE environ_ioncctype
    !------------------------------------------------------------------------------------
    !>
    !!
    !------------------------------------------------------------------------------------
    TYPE environ_electrolyte
        !--------------------------------------------------------------------------------
        !
        LOGICAL :: update = .FALSE.
        LOGICAL :: initialized = .FALSE.
        CHARACTER(LEN=80) :: electrolyte_entropy
        CHARACTER(LEN=80) :: ion_adsorption
        LOGICAL :: linearized = .FALSE.
        INTEGER :: ntyp
        TYPE(environ_ioncctype), ALLOCATABLE :: ioncctype(:)
        !
        REAL(DP) :: temperature
        REAL(DP) :: k2
        REAL(DP) :: cionmax
        REAL(DP) :: permittivity
        REAL(DP) :: adsorption_energy
        !
        TYPE(environ_boundary) :: boundary
        TYPE(environ_density) :: density
        !
        !--------------------------------------------------------------------------------
        ! The electrolyte switch function and related quantities
        !
        TYPE(environ_density) :: gamma
        TYPE(environ_density) :: dgamma
        !
        TYPE(environ_functions) :: function_
        !
        TYPE(environ_density) :: de_dboundary_second_order
        REAL(DP) :: energy_second_order
        REAL(DP) :: charge = 0.0_DP
        !
        !--------------------------------------------------------------------------------
    END TYPE environ_electrolyte
    !------------------------------------------------------------------------------------
    !>
    !!
    !------------------------------------------------------------------------------------
    TYPE environ_semiconductor
        !--------------------------------------------------------------------------------
        !
        LOGICAL :: update = .FALSE.
        LOGICAL :: initialized = .FALSE.
        !
        REAL(DP) :: temperature
        REAL(DP) :: permittivity
        REAL(DP) :: carrier_density
        REAL(DP) :: electrode_charge
        REAL(DP) :: charge_threshold
        REAL(DP) :: slab_charge = 0.D0
        !
        TYPE(environ_functions) :: simple
        TYPE(environ_density) :: density
        !
        REAL(DP) :: charge = 0.0_DP
        REAL(DP) :: flatband_fermi = 0.D0
        REAL(DP) :: bulk_sc_fermi = 0.D0
        REAL(DP) :: surf_area_per_sq_cm = 0.D0
        !
        !--------------------------------------------------------------------------------
    END TYPE environ_semiconductor
    !------------------------------------------------------------------------------------
    !
    !------------------------------------------------------------------------------------
CONTAINS
    !------------------------------------------------------------------------------------
    !>
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE create_environ_density(density, local_label)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        CHARACTER(LEN=80), INTENT(IN), OPTIONAL :: local_label
        !
        TYPE(environ_density), INTENT(INOUT) :: density
        !
        CHARACTER(LEN=80) :: sub_name = 'create_environ_density'
        !
        CHARACTER(LEN=80) :: label = 'density'
        !
        !--------------------------------------------------------------------------------
        !
        IF (PRESENT(local_label)) THEN
            density%label = local_label
        ELSE
            density%label = label
        END IF
        !
        NULLIFY (density%cell)
        !
        IF (ALLOCATED(density%of_r)) &
            CALL errore(sub_name, 'Trying to create an already allocated object', 1)
        !
        RETURN
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE create_environ_density
    !------------------------------------------------------------------------------------
    !>
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE init_environ_density(cell, density)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        TYPE(environ_cell), TARGET, INTENT(IN) :: cell
        !
        TYPE(environ_density), INTENT(INOUT) :: density
        !
        CHARACTER(LEN=80) :: sub_name = 'init_environ_density'
        !
        !--------------------------------------------------------------------------------
        !
        density%update = .FALSE.
        !
        IF (ASSOCIATED(density%cell)) &
            CALL errore(sub_name, 'Trying to associate an associated object', 1)
        !
        density%cell => cell
        !
        IF (ALLOCATED(density%of_r)) &
            CALL errore(sub_name, 'Trying to allocate an allocated object', 1)
        !
        ALLOCATE (density%of_r(density%cell%nnr))
        density%of_r = 0.D0
        !
        density%charge = 0.D0
        density%dipole = 0.D0
        density%quadrupole = 0.D0
        !
        RETURN
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE init_environ_density
    !------------------------------------------------------------------------------------
    !>
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE copy_environ_density(doriginal, dcopy)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        TYPE(environ_density), INTENT(IN) :: doriginal
        !
        TYPE(environ_density), INTENT(OUT) :: dcopy
        !
        CHARACTER(LEN=80) :: sub_name = 'copy_environ_density'
        !
        INTEGER :: n
        !
        !--------------------------------------------------------------------------------
        !
        IF (.NOT. ASSOCIATED(doriginal%cell)) &
            CALL errore(sub_name, 'Trying to copy a non associated object', 1)
        !
        dcopy%cell => doriginal%cell
        !
        dcopy%update = doriginal%update
        dcopy%label = doriginal%label
        dcopy%charge = doriginal%charge
        dcopy%dipole = doriginal%dipole
        dcopy%quadrupole = doriginal%quadrupole
        !
        IF (ALLOCATED(doriginal%of_r)) THEN
            n = SIZE(doriginal%of_r)
            !
            IF (ALLOCATED(dcopy%of_r)) DEALLOCATE (dcopy%of_r)
            !
            ALLOCATE (dcopy%of_r(n))
            dcopy%of_r = doriginal%of_r
        END IF
        !
        RETURN
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE copy_environ_density
    !------------------------------------------------------------------------------------
    !>
    !!
    !------------------------------------------------------------------------------------
    FUNCTION integrate_environ_density(density) RESULT(integral)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        TYPE(environ_density), INTENT(IN) :: density
        !
        REAL(DP) :: integral
        !
        !--------------------------------------------------------------------------------
        !
        integral = SUM(density%of_r(1:density%cell%ir_end))
        !
        CALL mp_sum(integral, density%cell%dfft%comm)
        !
        integral = integral * density%cell%domega
        !
        RETURN
        !
        !--------------------------------------------------------------------------------
    END FUNCTION integrate_environ_density
    !------------------------------------------------------------------------------------
    !>
    !!
    !------------------------------------------------------------------------------------
    FUNCTION scalar_product_environ_density(density1, density2) RESULT(scalar_product)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        TYPE(environ_density), INTENT(IN) :: density1, density2
        !
        INTEGER, POINTER :: ir_end
        REAL(DP) :: scalar_product
        !
        CHARACTER(LEN=80) :: fun_name = 'scalar_product_environ_density'
        !
        !--------------------------------------------------------------------------------
        !
        IF (.NOT. ASSOCIATED(density1%cell, density2%cell)) &
            CALL errore(fun_name, 'operation on fields with inconsistent domains', 1)
        !
        ir_end => density1%cell%ir_end
        scalar_product = DOT_PRODUCT(density1%of_r(1:ir_end), density2%of_r(1:ir_end))
        !
        CALL mp_sum(scalar_product, density1%cell%dfft%comm)
        !
        scalar_product = scalar_product * density1%cell%domega
        !
        RETURN
        !
        !--------------------------------------------------------------------------------
    END FUNCTION scalar_product_environ_density
    !------------------------------------------------------------------------------------
    !>
    !!
    !------------------------------------------------------------------------------------
    FUNCTION euclidean_norm_environ_density(density) RESULT(euclidean_norm)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        TYPE(environ_density), INTENT(IN) :: density
        !
        INTEGER, POINTER :: ir_end
        !
        REAL(DP) :: euclidean_norm
        !
        !--------------------------------------------------------------------------------
        !
        ir_end => density%cell%ir_end
        euclidean_norm = DOT_PRODUCT(density%of_r(1:ir_end), density%of_r(1:ir_end))
        !
        CALL mp_sum(euclidean_norm, density%cell%dfft%comm)
        !
        RETURN
        !
        !--------------------------------------------------------------------------------
    END FUNCTION euclidean_norm_environ_density
    !------------------------------------------------------------------------------------
    !>
    !!
    !------------------------------------------------------------------------------------
    FUNCTION quadratic_mean_environ_density(density) RESULT(quadratic_mean)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        TYPE(environ_density), INTENT(IN) :: density
        !
        INTEGER, POINTER :: ir_end
        !
        REAL(DP) :: quadratic_mean
        !
        !--------------------------------------------------------------------------------
        !
        ir_end => density%cell%ir_end
        quadratic_mean = DOT_PRODUCT(density%of_r(1:ir_end), density%of_r(1:ir_end))
        !
        CALL mp_sum(quadratic_mean, density%cell%dfft%comm)
        !
        quadratic_mean = SQRT(quadratic_mean / density%cell%ntot)
        !
        RETURN
        !
        !--------------------------------------------------------------------------------
    END FUNCTION quadratic_mean_environ_density
    !------------------------------------------------------------------------------------
    !>
    !!
    !------------------------------------------------------------------------------------
    FUNCTION quadratic_mean_environ_density_old(density) RESULT(quadratic_mean)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        TYPE(environ_density), INTENT(IN) :: density
        !
        INTEGER, POINTER :: ir_end
        !
        REAL(DP) :: quadratic_mean
        !
        !--------------------------------------------------------------------------------
        !
        ir_end => density%cell%ir_end
        quadratic_mean = DOT_PRODUCT(density%of_r(1:ir_end), density%of_r(1:ir_end))
        !
        CALL mp_sum(quadratic_mean, density%cell%dfft%comm)
        !
        quadratic_mean = SQRT(quadratic_mean) / density%cell%ntot
        !
        RETURN
        !
        !--------------------------------------------------------------------------------
    END FUNCTION quadratic_mean_environ_density_old
    !------------------------------------------------------------------------------------
    !>
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE multipoles_environ_density(density, origin, monopole, dipole, quadrupole)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        TYPE(environ_density), TARGET, INTENT(IN) :: density
        REAL(DP), INTENT(IN) :: origin(3)
        !
        REAL(DP), INTENT(OUT) :: monopole
        REAL(DP), DIMENSION(3), INTENT(OUT) :: dipole, quadrupole
        !
        TYPE(environ_cell), POINTER :: cell
        !
        LOGICAL :: physical
        INTEGER :: ir
        REAL(DP) :: r(3), rhoir, r2
        INTEGER :: dim, axis
        !
        !--------------------------------------------------------------------------------
        !
        cell => density%cell
        !
        monopole = 0.D0
        dipole = 0.D0
        quadrupole = 0.D0
        !
        dim = 0
        axis = 3
        !
        DO ir = 1, cell%ir_end
            !
            CALL ir2r(cell, ir, r, physical) ! position in real space grid
            !
            IF (.NOT. physical) CYCLE ! do not include points outside the physical range
            !
            CALL displacement(dim, axis, r, origin, r) ! displacement from origin
            !
            CALL minimum_image(cell, r, r2) ! minimum image convention
            !
            rhoir = density%of_r(ir)
            !
            !----------------------------------------------------------------------------
            ! Multipoles
            !
            monopole = monopole + rhoir
            dipole = dipole + rhoir * r
            quadrupole = quadrupole + rhoir * r**2
            !
            !----------------------------------------------------------------------------
            !
        END DO
        !
        CALL mp_sum(monopole, cell%dfft%comm)
        !
        CALL mp_sum(dipole, cell%dfft%comm)
        !
        CALL mp_sum(quadrupole, cell%dfft%comm)
        !
        monopole = monopole * cell%domega
        dipole = dipole * cell%domega * cell%alat
        quadrupole = quadrupole * cell%domega * cell%alat**2
        !
        RETURN
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE multipoles_environ_density
    !------------------------------------------------------------------------------------
    !>
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE update_environ_density(density)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        TYPE(environ_density), INTENT(INOUT) :: density
        !
        !--------------------------------------------------------------------------------
        !
        CALL multipoles_environ_density(density, density%cell%origin, &
                                        density%charge, density%dipole, &
                                        density%quadrupole)
        !
        RETURN
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE update_environ_density
    !------------------------------------------------------------------------------------
    !>
    !! #TODO: unused function
    !!
    !------------------------------------------------------------------------------------
    FUNCTION dipole_of_origin(density, origin) RESULT(dipole)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        TYPE(environ_density), INTENT(IN) :: density
        !
        REAL(DP), DIMENSION(3) :: origin, dipole
        !
        !--------------------------------------------------------------------------------
        !
        dipole = density%dipole + density%charge * (density%cell%origin - origin)
        !
        RETURN
        !
        !--------------------------------------------------------------------------------
    END FUNCTION dipole_of_origin
    !------------------------------------------------------------------------------------
    !>
    !! #TODO: unused function
    !!
    !------------------------------------------------------------------------------------
    FUNCTION quadrupole_of_origin(density, origin) RESULT(quadrupole)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        TYPE(environ_density), INTENT(IN) :: density
        !
        REAL(DP), DIMENSION(3) :: origin, quadrupole
        !
        !--------------------------------------------------------------------------------
        !
        quadrupole = density%quadrupole + &
                     density%charge * (density%cell%origin - origin)**2 + &
                     2.D0 * density%dipole * (density%cell%origin - origin)
        !
        RETURN
        !
        !--------------------------------------------------------------------------------
    END FUNCTION quadrupole_of_origin
    !------------------------------------------------------------------------------------
    !>
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE destroy_environ_density(density)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        TYPE(environ_density), INTENT(INOUT) :: density
        !
        CHARACTER(LEN=80) :: sub_name = 'destroy_environ_density'
        !
        !--------------------------------------------------------------------------------
        !
        density%update = .FALSE.
        !
        IF (.NOT. ASSOCIATED(density%cell)) &
            CALL errore(sub_name, 'Trying to destroy a non associated object', 1)
        !
        NULLIFY (density%cell)
        !
        IF (.NOT. ALLOCATED(density%of_r)) &
            CALL errore(sub_name, 'Trying to destroy a non allocated object', 1)
        !
        DEALLOCATE (density%of_r)
        !
        RETURN
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE destroy_environ_density
    !------------------------------------------------------------------------------------
    !>
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE create_environ_gradient(gradient, label)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        CHARACTER(LEN=80), INTENT(IN), OPTIONAL :: label
        !
        TYPE(environ_gradient), INTENT(INOUT) :: gradient
        !
        CHARACTER(LEN=80) :: modulus_label
        !
        CHARACTER(LEN=80) :: sub_name = 'destroy_environ_density'
        !
        !--------------------------------------------------------------------------------
        !
        IF (PRESENT(label)) THEN
            gradient%label = label
            modulus_label = TRIM(ADJUSTL(label))//'_modulus'
        ELSE
            gradient%label = 'gradient'
            modulus_label = 'gradient_modulus'
        END IF
        !
        NULLIFY (gradient%cell)
        !
        IF (ALLOCATED(gradient%of_r)) &
            CALL errore(sub_name, 'Trying to create an already allocated object', 1)
        !
        CALL create_environ_density(gradient%modulus, modulus_label)
        !
        RETURN
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE create_environ_gradient
    !------------------------------------------------------------------------------------
    !>
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE init_environ_gradient(cell, gradient)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        TYPE(environ_cell), TARGET, INTENT(IN) :: cell
        !
        TYPE(environ_gradient), INTENT(INOUT) :: gradient
        !
        CHARACTER(LEN=80) :: sub_name = 'init_environ_gradient'
        !
        !--------------------------------------------------------------------------------
        !
        gradient%update = .FALSE.
        !
        IF (ASSOCIATED(gradient%cell)) &
            CALL errore(sub_name, 'Trying to associate an associated object', 1)
        !
        gradient%cell => cell
        !
        IF (ALLOCATED(gradient%of_r)) &
            CALL errore(sub_name, 'Trying to allocate an allocated object', 1)
        !
        ALLOCATE (gradient%of_r(3, gradient%cell%nnr))
        gradient%of_r = 0.D0
        !
        CALL init_environ_density(cell, gradient%modulus)
        !
        RETURN
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE init_environ_gradient
    !------------------------------------------------------------------------------------
    !>
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE copy_environ_gradient(goriginal, gcopy)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        TYPE(environ_gradient), INTENT(IN) :: goriginal
        !
        TYPE(environ_gradient), INTENT(OUT) :: gcopy
        !
        INTEGER :: n
        !
        CHARACTER(LEN=80) :: sub_name = 'copy_environ_gradient'
        !
        !--------------------------------------------------------------------------------
        !
        IF (.NOT. ASSOCIATED(goriginal%cell)) &
            CALL errore(sub_name, 'Trying to copy a non associated object', 1)
        !
        gcopy%cell => goriginal%cell
        !
        gcopy%update = goriginal%update
        gcopy%label = goriginal%label
        !
        IF (ALLOCATED(goriginal%of_r)) THEN
            n = SIZE(goriginal%of_r, 2)
            !
            IF (ALLOCATED(gcopy%of_r)) DEALLOCATE (gcopy%of_r)
            !
            ALLOCATE (gcopy%of_r(3, n))
            gcopy%of_r = goriginal%of_r
        END IF
        !
        CALL copy_environ_density(goriginal%modulus, gcopy%modulus)
        !
        RETURN
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE copy_environ_gradient
    !------------------------------------------------------------------------------------
    !>
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE update_gradient_modulus(gradient)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        TYPE(environ_gradient), INTENT(INOUT) :: gradient
        !
        INTEGER, POINTER :: ir_end
        !
        !--------------------------------------------------------------------------------
        !
        ir_end => gradient%cell%ir_end
        !
        gradient%modulus%of_r(1:ir_end) = SQRT(gradient%of_r(1, 1:ir_end)**2 + &
                                               gradient%of_r(2, 1:ir_end)**2 + &
                                               gradient%of_r(3, 1:ir_end)**2)
        !
        RETURN
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE update_gradient_modulus
    !------------------------------------------------------------------------------------
    !>
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE destroy_environ_gradient(gradient)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        TYPE(environ_gradient), INTENT(INOUT) :: gradient
        !
        CHARACTER(LEN=80) :: sub_name = 'destroy_environ_gradient'
        !
        !--------------------------------------------------------------------------------
        !
        gradient%update = .FALSE.
        !
        IF (.NOT. ASSOCIATED(gradient%cell)) &
            CALL errore(sub_name, 'Trying to destroy a non associated object', 1)
        !
        NULLIFY (gradient%cell)
        !
        IF (.NOT. ALLOCATED(gradient%of_r)) &
            CALL errore(sub_name, 'Trying to destroy a non allocated object', 1)
        !
        DEALLOCATE (gradient%of_r)
        !
        CALL destroy_environ_density(gradient%modulus)
        !
        RETURN
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE destroy_environ_gradient
    !------------------------------------------------------------------------------------
    !>
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE scalar_product_environ_gradient(gradA, gradB, dens)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        TYPE(environ_gradient), INTENT(IN) :: gradA, gradB
        !
        TYPE(environ_density), INTENT(INOUT) :: dens
        !
        INTEGER :: ir
        !
        CHARACTER(LEN=80) :: sub_name = 'scalar_product_environ_gradient'
        !
        !--------------------------------------------------------------------------------
        !
        dens%of_r = 0.D0
        !
        IF (.NOT. ASSOCIATED(gradA%cell, gradB%cell)) &
            CALL errore(sub_name, 'Missmatch in domain of input gradients', 1)
        !
        IF (.NOT. ASSOCIATED(gradA%cell, dens%cell)) &
            CALL errore(sub_name, 'Missmatch in domain of input and output', 1)
        !
        DO ir = 1, dens%cell%ir_end
            dens%of_r(ir) = SUM(gradA%of_r(:, ir) * gradB%of_r(:, ir))
        END DO
        !
        RETURN
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE scalar_product_environ_gradient
    !------------------------------------------------------------------------------------
    !>
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE scalar_product_environ_hessian(hess, gradin, gradout)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        TYPE(environ_hessian), INTENT(IN) :: hess
        TYPE(environ_gradient), INTENT(IN) :: gradin
        !
        TYPE(environ_gradient), INTENT(INOUT) :: gradout
        !
        INTEGER :: ir, ipol
        !
        CHARACTER(LEN=80) :: sub_name = 'scalar_product_environ_hessian'
        !
        !--------------------------------------------------------------------------------
        !
        gradout%of_r = 0.D0
        !
        IF (.NOT. ASSOCIATED(gradin%cell, hess%cell)) &
            CALL errore(sub_name, 'Missmatch in domain of input hessian/gradients', 1)
        !
        IF (.NOT. ASSOCIATED(gradin%cell, gradout%cell)) &
            CALL errore(sub_name, 'Missmatch in domain of input and output', 1)
        !
        DO ir = 1, hess%cell%ir_end
            !
            DO ipol = 1, 3
                gradout%of_r(ipol, ir) = SUM(hess%of_r(:, ipol, ir) * gradin%of_r(:, ir))
            END DO
            !
        END DO
        !
        RETURN
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE scalar_product_environ_hessian
    !------------------------------------------------------------------------------------
    !>
    !!
    !------------------------------------------------------------------------------------
    FUNCTION scalar_product_environ_gradient_density(gradient, density) RESULT(res)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        TYPE(environ_gradient), INTENT(IN) :: gradient
        TYPE(environ_density), INTENT(IN) :: density
        !
        REAL(DP) :: res(3)
        !
        INTEGER, POINTER :: ir_end
        !
        INTEGER :: ipol
        REAL(DP) :: scalar_product
        !
        CHARACTER(LEN=80) :: sub_name = 'scalar_product_environ_gradient_density'
        !
        !--------------------------------------------------------------------------------
        !
        res = 0.D0
        !
        IF (.NOT. ASSOCIATED(gradient%cell, density%cell)) &
            CALL errore(sub_name, 'Missmatch in domain of input vectors', 1)
        !
        ir_end => density%cell%ir_end
        !
        DO ipol = 1, 3
            !
            scalar_product = DOT_PRODUCT(gradient%of_r(ipol, 1:ir_end), &
                                         density%of_r(1:ir_end))
            !
            CALL mp_sum(scalar_product, density%cell%dfft%comm)
            !
            res(ipol) = scalar_product * density%cell%domega
        END DO
        !
        RETURN
        !
        !--------------------------------------------------------------------------------
    END FUNCTION scalar_product_environ_gradient_density
    !------------------------------------------------------------------------------------
    !>
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE create_environ_hessian(hessian, label)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        CHARACTER(LEN=80), OPTIONAL, INTENT(IN) :: label
        !
        TYPE(environ_hessian), INTENT(INOUT) :: hessian
        !
        CHARACTER(LEN=80) :: laplacian_label
        !
        CHARACTER(LEN=80) :: sub_name = 'destroy_environ_hessian'
        !
        !--------------------------------------------------------------------------------
        !
        IF (PRESENT(label)) THEN
            hessian%label = label
            laplacian_label = TRIM(ADJUSTL(label))//'_laplacian'
        ELSE
            hessian%label = 'hessian'
            laplacian_label = 'hessian_laplacian'
        END IF
        !
        NULLIFY (hessian%cell)
        !
        IF (ALLOCATED(hessian%of_r)) &
            CALL errore(sub_name, 'Trying to create an already allocated object', 1)
        !
        CALL create_environ_density(hessian%laplacian, laplacian_label)
        !
        RETURN
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE create_environ_hessian
    !------------------------------------------------------------------------------------
    !>
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE init_environ_hessian(cell, hessian)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        TYPE(environ_cell), TARGET, INTENT(IN) :: cell
        !
        TYPE(environ_hessian), INTENT(INOUT) :: hessian
        !
        CHARACTER(LEN=80) :: sub_name = 'init_environ_hessian'
        !
        !--------------------------------------------------------------------------------
        !
        hessian%update = .FALSE.
        !
        IF (ASSOCIATED(hessian%cell)) &
            CALL errore(sub_name, 'Trying to associate an associated object', 1)
        !
        hessian%cell => cell
        !
        IF (ALLOCATED(hessian%of_r)) &
            CALL errore(sub_name, 'Trying to allocate an allocated object', 1)
        !
        ALLOCATE (hessian%of_r(3, 3, hessian%cell%nnr))
        hessian%of_r = 0.D0
        !
        CALL init_environ_density(cell, hessian%laplacian)
        !
        RETURN
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE init_environ_hessian
    !------------------------------------------------------------------------------------
    !>
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE copy_environ_hessian(horiginal, hcopy)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        TYPE(environ_hessian), INTENT(IN) :: horiginal
        !
        TYPE(environ_hessian), INTENT(OUT) :: hcopy
        !
        INTEGER :: n
        !
        CHARACTER(LEN=80) :: sub_name = 'copy_environ_hessian'
        !
        !--------------------------------------------------------------------------------
        !
        IF (.NOT. ASSOCIATED(horiginal%cell)) &
            CALL errore(sub_name, 'Trying to copy a non associated object', 1)
        !
        hcopy%cell => horiginal%cell
        !
        hcopy%update = horiginal%update
        hcopy%label = horiginal%label
        !
        IF (ALLOCATED(horiginal%of_r)) THEN
            n = SIZE(horiginal%of_r, 3)
            !
            IF (ALLOCATED(hcopy%of_r)) DEALLOCATE (hcopy%of_r)
            !
            ALLOCATE (hcopy%of_r(3, 3, n))
            hcopy%of_r = horiginal%of_r
        END IF
        !
        CALL copy_environ_density(horiginal%laplacian, hcopy%laplacian)
        !
        RETURN
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE copy_environ_hessian
    !------------------------------------------------------------------------------------
    !>
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE update_hessian_laplacian(hessian)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        TYPE(environ_hessian), INTENT(INOUT) :: hessian
        !
        INTEGER, POINTER :: ir_end
        !
        !--------------------------------------------------------------------------------
        !
        ir_end => hessian%cell%ir_end
        !
        hessian%laplacian%of_r(1:ir_end) = hessian%of_r(1, 1, 1:ir_end) + &
                                           hessian%of_r(2, 2, 1:ir_end) + &
                                           hessian%of_r(3, 3, 1:ir_end)
        !
        RETURN
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE update_hessian_laplacian
    !------------------------------------------------------------------------------------
    !>
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE destroy_environ_hessian(hessian)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        TYPE(environ_hessian), INTENT(INOUT) :: hessian
        !
        CHARACTER(LEN=80) :: sub_name = 'destroy_environ_hessian'
        !
        hessian%update = .FALSE.
        !
        !--------------------------------------------------------------------------------
        !
        IF (.NOT. ASSOCIATED(hessian%cell)) &
            CALL errore(sub_name, 'Trying to destroy a non associated object', 1)
        !
        NULLIFY (hessian%cell)
        !
        IF (.NOT. ALLOCATED(hessian%of_r)) &
            CALL errore(sub_name, 'Trying to destroy a non allocated object', 1)
        !
        DEALLOCATE (hessian%of_r)
        !
        CALL destroy_environ_density(hessian%laplacian)
        !
        RETURN
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE destroy_environ_hessian
    !------------------------------------------------------------------------------------
    !>
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE create_environ_electrons(electrons)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        TYPE(environ_electrons), INTENT(INOUT) :: electrons
        !
        CHARACTER(LEN=80) :: label = 'electrons'
        !
        !--------------------------------------------------------------------------------
        !
        electrons%update = .FALSE.
        electrons%number = 0
        !
        ! BACKWARD COMPATIBILITY
        ! Compatible with QE-6.0 QE-6.1.X QE-6.2.X QE-6.3.X
        ! electrons%nspin = 1
        ! Compatible with QE-6.4.X QE-GIT
        ! END BACKWARD COMPATIBILITY
        electrons%charge = 0.D0
        !
        CALL create_environ_density(electrons%density, label)
        !
        RETURN
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE create_environ_electrons
    !------------------------------------------------------------------------------------
    !>
    !!
    !------------------------------------------------------------------------------------
    ! BACKWARD COMPATIBILITY
    ! Compatible with QE-6.0 QE-6.1.X QE-6.2.X QE-6.3.X
    ! SUBROUTINE init_environ_electrons_first(nelec, nspin, electrons)
    ! Compatible with QE-6.4.X QE-GIT
    SUBROUTINE init_environ_electrons_first(nelec, electrons)
        ! END BACKWARD COMPATIBILITY
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        INTEGER, INTENT(IN) :: nelec
        ! BACKWARD COMPATIBILITY
        ! Compatible with QE-6.0 QE-6.1.X QE-6.2.X QE-6.3.X
        ! INTEGER, INTENT(IN) :: nspin
        ! Compatible with QE-6.4.X QE-GIT
        !
        ! END BACKWARD COMPATIBILITY
        TYPE(environ_electrons), INTENT(INOUT) :: electrons
        !
        !--------------------------------------------------------------------------------
        !
        electrons%initialized = .FALSE.
        electrons%number = nelec
        !
        ! BACKWARD COMPATIBILITY
        ! Compatible with QE-6.0 QE-6.1.X QE-6.2.X QE-6.3.X
        ! electrons%nspin = nspin
        ! Compatible with QE-6.4.X QE-GIT
        ! END BACKWARD COMPATIBILITY
        !
        RETURN
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE init_environ_electrons_first
    !------------------------------------------------------------------------------------
    !>
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE init_environ_electrons_second(cell, electrons)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        TYPE(environ_cell), INTENT(IN) :: cell
        !
        TYPE(environ_electrons), INTENT(INOUT) :: electrons
        !
        !--------------------------------------------------------------------------------
        !
        CALL init_environ_density(cell, electrons%density)
        !
        electrons%initialized = .TRUE.
        !
        RETURN
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE init_environ_electrons_second
    !------------------------------------------------------------------------------------
    !>
    !!
    !------------------------------------------------------------------------------------
    ! BACKWARD COMPATIBILITY
    ! Compatible with QE-6.0 QE-6.1.X QE-6.2.X QE-6.3.X
    ! SUBROUTINE update_environ_electrons(nspin, nnr, rho, electrons, nelec)
    ! Compatible with QE-6.4.X QE-GIT
    SUBROUTINE update_environ_electrons(nnr, rho, electrons, nelec)
        ! END BACKWARD COMPATIBILITY
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        INTEGER, INTENT(IN) :: nnr
        !
        ! BACKWARD COMPATIBILITY
        ! Compatible with QE-6.0 QE-6.1.X QE-6.2.X QE-6.3.X
        ! INTEGER, INTENT(IN) :: nspin
        ! REAL(DP), INTENT(IN) :: rho(nnr, nspin)
        ! Compatible with QE-6.4.X QE-GIT
        REAL(DP), INTENT(IN) :: rho(nnr)
        ! END BACKWARD COMPATIBILITY
        !
        REAL(DP), INTENT(IN), OPTIONAL :: nelec
        !
        TYPE(environ_electrons), INTENT(INOUT) :: electrons
        !
        REAL(DP), PARAMETER :: tol = 1.D-4
        REAL(DP) :: charge
        !
        CHARACTER(LEN=80) :: sub_name = 'update_environ_electrons'
        !
        !--------------------------------------------------------------------------------
        ! Check on dimensions
        !
        ! BACKWARD COMPATIBILITY
        ! Compatible with QE-6.0 QE-6.1.X QE-6.2.X QE-6.3.X
        ! IF (nspin /= electrons%nspin) &
        !     CALL errore(sub_name, 'Missmatch in spin size', 1)
        ! Compatible with QE-6.4.X QE-GIT
        ! END BACKWARD COMPATIBILITY
        !
        IF (nnr /= electrons%density%cell%nnr) &
            CALL errore(sub_name, 'Missmatch in grid size', 1)
        !
        !--------------------------------------------------------------------------------
        ! Assign input density to electrons%density%of_r
        !
        ! BACKWARD COMPATIBILITY
        ! Compatible with QE-5.X QE-6.1.X QE-6.2.X QE-6.3.X
        ! electrons%density%of_r(:) = rho(:, 1)
        ! IF (electrons%nspin == 2) &
        !     electrons%density%of_r(:) = electrons%density%of_r(:) + rho(:, 2)
        ! Compatible with QE-6.4.X and QE-GIT
        electrons%density%of_r = rho
        ! END BACKWARD COMPATIBILITY
        !
        !--------------------------------------------------------------------------------
        ! Update integral of electronic density and, if provided, check
        ! against input value
        !
        electrons%charge = integrate_environ_density(electrons%density)
        electrons%number = NINT(electrons%charge)
        !
        IF (PRESENT(nelec)) THEN
            !
            IF (ABS(electrons%charge - nelec) > tol) &
                CALL errore(sub_name, 'Missmatch in integrated electronic charge', 1)
            !
        END IF
        !
        RETURN
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE update_environ_electrons
    !------------------------------------------------------------------------------------
    !>
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE destroy_environ_electrons(lflag, electrons)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        LOGICAL, INTENT(IN) :: lflag ! #TODO: unused variable
        !
        TYPE(environ_electrons), INTENT(INOUT) :: electrons
        !
        !--------------------------------------------------------------------------------
        !
        IF (electrons%initialized) THEN
            !
            CALL destroy_environ_density(electrons%density)
            !
            electrons%charge = 0.D0
            electrons%initialized = .FALSE.
        END IF
        !
        RETURN
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE destroy_environ_electrons
    !------------------------------------------------------------------------------------
    !>
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE create_environ_system(system)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        TYPE(environ_system), INTENT(INOUT) :: system
        !
        !--------------------------------------------------------------------------------
        !
        system%update = .FALSE.
        system%ntyp = 0
        system%dim = 0
        system%axis = 1
        system%pos = 0.D0
        system%width = 0.D0
        NULLIFY (system%ions)
        !
        RETURN
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE create_environ_system
    !------------------------------------------------------------------------------------
    !>
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE init_environ_system(ntyp, dim, axis, ions, system)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        INTEGER, INTENT(IN) :: ntyp, dim, axis
        TYPE(environ_ions), TARGET, INTENT(IN) :: ions
        !
        TYPE(environ_system), INTENT(INOUT) :: system
        !
        CHARACTER(LEN=80) :: sub_name = 'init_environ_system'
        !
        !--------------------------------------------------------------------------------
        !
        system%ntyp = ntyp
        system%dim = dim
        system%axis = axis
        !
        system%ions => ions
        !
        RETURN
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE init_environ_system
    !------------------------------------------------------------------------------------
    !>
    !! Given the system definition compute position (centre of charge)
    !! and width (maximum distance from centre) of the system.
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE update_environ_system(system)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        TYPE(environ_system), INTENT(INOUT) :: system
        !
        CHARACTER(LEN=80) :: sub_name = 'update_environ_system'
        !
        INTEGER :: i, icor, max_ntyp
        REAL(DP) :: charge, dist
        INTEGER, POINTER :: ityp
        REAL(DP), POINTER :: zv
        !
        !--------------------------------------------------------------------------------
        !
        IF (.NOT. ASSOCIATED(system%ions)) &
            CALL errore(sub_name, 'Trying to use a non associated object', 1)
        !
        system%pos = 0.D0
        system%width = 0.D0
        !
        max_ntyp = system%ntyp
        !
        IF (system%ntyp == 0) max_ntyp = system%ions%ntyp
        !
        charge = 0.D0
        !
        DO i = 1, system%ions%number
            ityp => system%ions%ityp(i)
            !
            IF (ityp > max_ntyp) CYCLE
            !
            zv => system%ions%iontype(ityp)%zv
            charge = charge + zv
            system%pos(:) = system%pos(:) + system%ions%tau(:, i) * zv
        END DO
        !
        IF (ABS(charge) < 1.D-8) &
            CALL errore(sub_name, 'System charge is zero', 1)
        !
        system%pos(:) = system%pos(:) / charge
        !
        system%width = 0.D0
        !
        DO i = 1, system%ions%number
            ityp => system%ions%ityp(i)
            !
            IF (ityp > max_ntyp) CYCLE
            !
            dist = 0.D0
            !
            DO icor = 1, 3
                !
                IF ((system%dim == 1 .AND. icor == system%axis) .OR. &
                    (system%dim == 2 .AND. icor /= system%axis)) CYCLE
                !
                dist = dist + (system%ions%tau(icor, i) - system%pos(icor))**2
            END DO
            !
            ! need to modify it into a smooth maximum to compute derivatives
            system%width = MAX(system%width, dist)
        END DO
        !
        system%width = SQRT(system%width)
        !
        RETURN
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE update_environ_system
    !------------------------------------------------------------------------------------
    !>
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE destroy_environ_system(lflag, system)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        LOGICAL, INTENT(IN) :: lflag
        !
        TYPE(environ_system), INTENT(INOUT) :: system
        !
        CHARACTER(LEN=80) :: sub_name = 'destroy_environ_system'
        !
        !--------------------------------------------------------------------------------
        !
        IF (lflag) THEN
            !
            IF (.NOT. ASSOCIATED(system%ions)) &
                CALL errore(sub_name, 'Trying to destroy a non associated object', 1)
            !
            NULLIFY (system%ions)
        END IF
        !
        RETURN
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE destroy_environ_system
    !------------------------------------------------------------------------------------
    !
    !------------------------------------------------------------------------------------
END MODULE environ_types
!----------------------------------------------------------------------------------------
