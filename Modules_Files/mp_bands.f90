!
! Copyright (C) 2013 Quantum ESPRESSO group
! This file is distributed under the terms of the
! GNU General Public License. See the file `License'
! in the root directory of the present distribution,
! or http://www.gnu.org/copyleft/gpl.txt .
!
!----------------------------------------------------------------------------
MODULE env_mp_bands
  !----------------------------------------------------------------------------
  !
  USE env_mp, ONLY : env_mp_barrier, env_mp_bcast, env_mp_size, env_mp_rank, env_mp_comm_split
  USE env_parallel_include
  !
  IMPLICIT NONE 
  SAVE
  !
  ! ... Band groups (processors within a pool of bands)
  ! ... Subdivision of pool group, used for parallelization over bands
  !
  INTEGER :: nbgrp       = 1  ! number of band groups
  INTEGER :: nproc_bgrp  = 1  ! number of processors within a band group
  INTEGER :: me_bgrp     = 0  ! index of the processor within a band group
  INTEGER :: root_bgrp   = 0  ! index of the root processor within a band group
  INTEGER :: my_bgrp_id  = 0  ! index of my band group
  INTEGER :: root_bgrp_id     = 0  ! index of root band group
  INTEGER :: inter_bgrp_comm  = 0  ! inter band group communicator
  INTEGER :: intra_bgrp_comm  = 0  ! intra band group communicator  
  ! Next variable is .T. if band parallelization is performed inside H\psi 
  ! and S\psi, .F. otherwise (band parallelization can be performed outside
  ! H\psi and S\psi, though)  
  LOGICAL :: use_bgrp_in_hpsi = .FALSE.
  !
  ! ... "task" groups (for band parallelization of FFT)
  !
  INTEGER :: ntask_groups = 1  ! number of proc. in an orbital "task group"
  !
  ! ... "nyfft" groups (to push FFT parallelization beyond the nz-planes limit)
  INTEGER :: nyfft = 1         ! number of y-fft groups. By default =1, i.e. y-ffts are done by a single proc 
  !
CONTAINS
  !
  !----------------------------------------------------------------------------
  SUBROUTINE env_mp_start_bands( nband_, ntg_, nyfft_, parent_comm )
    !---------------------------------------------------------------------------
    !
    ! ... Divide processors (of the "parent_comm" group) into nband_ pools
    ! ... Requires: nband_, read from command line
    ! ...           parent_comm, typically processors of a k-point pool
    ! ...           (intra_pool_comm)
    !
    IMPLICIT NONE
    !
    INTEGER, INTENT(IN) :: nband_, parent_comm
    INTEGER, INTENT(IN), OPTIONAL :: ntg_, nyfft_
    !
    INTEGER :: parent_nproc = 1, parent_mype = 0
    !
#if defined (__MPI)
    !
    parent_nproc = env_mp_size( parent_comm )
    parent_mype  = env_mp_rank( parent_comm )
    !
    ! ... nband_ must have been previously read from command line argument
    ! ... by a call to routine get_command_line
    !
    nbgrp = nband_
    !
    IF ( nbgrp < 1 .OR. nbgrp > parent_nproc ) CALL env_errore( 'mp_start_bands',&
                          'invalid number of band groups, out of range', 1 )
    IF ( MOD( parent_nproc, nbgrp ) /= 0 ) CALL env_errore( 'mp_start_bands', &
        'n. of band groups  must be divisor of parent_nproc', 1 )
    !
    ! set logical flag so that band parallelization in H\psi is allowed
    ! (can be disabled before calling H\psi if not desired)
    !
    use_bgrp_in_hpsi = ( nbgrp > 1 )
    ! 
    ! ... Set number of processors per band group
    !
    nproc_bgrp = parent_nproc / nbgrp
    !
    ! ... set index of band group for this processor   ( 0 : nbgrp - 1 )
    !
    my_bgrp_id = parent_mype / nproc_bgrp
    !
    ! ... set index of processor within the image ( 0 : nproc_image - 1 )
    !
    me_bgrp    = MOD( parent_mype, nproc_bgrp )
    !
    CALL env_mp_barrier( parent_comm )
    !
    ! ... the intra_bgrp_comm communicator is created
    !
    CALL env_mp_comm_split( parent_comm, my_bgrp_id, parent_mype, intra_bgrp_comm )
    !
    CALL env_mp_barrier( parent_comm )
    !
    ! ... the inter_bgrp_comm communicator is created                     
    !     
    CALL env_mp_comm_split( parent_comm, me_bgrp, parent_mype, inter_bgrp_comm )  
    !
    IF ( PRESENT(ntg_) ) THEN
       ntask_groups = ntg_
    END IF
    IF ( PRESENT(nyfft_) ) THEN
       nyfft = nyfft_
    END IF
    call env_errore('mp_bands',' nyfft value incompatible with nproc_bgrp ', MOD(nproc_bgrp, nyfft) )
    !
#endif
    RETURN
    !
  END SUBROUTINE env_mp_start_bands
  !
END MODULE env_mp_bands
!
!     
MODULE env_mp_bands_TDDFPT
!
! NB: These two variables used to be in mp_bands and are loaded from mp_global in TDDFPT 
!     I think they would better stay in a TDDFPT specific module but leave them here not to
!     be too invasive on a code I don't know well. SdG
!     
  INTEGER :: ibnd_start = 0              ! starting band index used in bgrp parallelization
  INTEGER :: ibnd_end = 0                ! ending band index used in bgrp parallelization
!     
END MODULE env_mp_bands_TDDFPT
!     
