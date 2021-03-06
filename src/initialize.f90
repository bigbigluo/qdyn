module initialize

  implicit none
  private

  public :: init_all

contains

!=============================================================
subroutine init_all(pb)

  use problem_class
  use mesh, only : init_mesh
  use constants, only : PI
  use my_mpi, only: is_MPI_master
  use fault_stress, only : init_kernel
  use output, only : ot_init, ox_init
  use friction, only : set_theta_star, friction_mu
!!$  use omp_lib

  type(problem_type), intent(inout) :: pb

!  integer :: TID, NTHREADS

  call init_mesh(pb%mesh)

 ! dt_max & perturbation
 ! if periodic loading, set time step smaller than a fraction of loading period
  if (pb%Aper /= 0.d0 .and. pb%Tper > 0.d0) then
    if (pb%dt_max > 0.d0) then
      pb%dt_max = min(pb%dt_max,0.2d0*pb%Tper)
    else
      pb%dt_max = 0.2d0*pb%Tper
    endif
  endif
  if (pb%Tper > 0.d0) then
    pb%Omper = 2.d0*PI/pb%Tper
  else
    pb%Omper = 0.d0
  endif

 ! impedance 
  if (pb%beta > 0d0) then
    pb%zimpedance = 0.5d0*pb%smu/pb%beta
  else
    pb%zimpedance = 0.d0
  endif
  if (is_mpi_master()) write(6,*) 'Impedance = ', pb%zimpedance

  pb%slip = 0d0
  call set_theta_star(pb) ! ref theta value
  pb%tau_init = pb%sigma * friction_mu(pb%v,pb%theta,pb) + pb%coh
  pb%tau = pb%tau_init

 ! init value for solver
  pb%time = 0.d0
  pb%itstop = -1
  pb%it = 0

  call init_kernel(pb%lam,pb%smu,pb%mesh,pb%kernel)
  call ot_init(pb)
  call ox_init(pb)

  if (is_mpi_master()) write(6,*) 'Initialization completed'

  ! Info about threads
!!$OMP PARALLEL PRIVATE(NTHREADS, TID)
!!$  TID = OMP_GET_THREAD_NUM()
!!$  write(6,*) 'Thread index = ', TID
!!$OMP BARRIER
!!$  if (TID == 0) then
!!$    NTHREADS = OMP_GET_NUM_THREADS()
!!$    write(6,*) 'Total number of threads = ', NTHREADS
!!$  end if
!!$OMP END PARALLEL

end subroutine init_all

end module initialize
