!Module for derivs

module derivs_all

  implicit none

  private

  public :: derivs


contains


!====================Subroutine derivs===========================
!-------Compute theta, vslip and time deriv for one time step----
!-------Call rdft in compute_stress : real DFT-------------------
!----------------------------------------------------------------

subroutine derivs(time,yt,dydt,pb)

  use problem_class
  use fault_stress, only : compute_stress
  use friction, only : dtheta_dt, dmu_dv_dtheta

  type(problem_type), intent(inout) :: pb
  double precision, intent(in) :: time, yt(pb%neqs*pb%mesh%nn)
  double precision, intent(out) :: dydt(pb%neqs*pb%mesh%nn)

  double precision, dimension(pb%mesh%nn) :: dmu_dv, dmu_dtheta
  double precision, dimension(pb%mesh%nn) :: sigma, dsigma_dt
  double precision :: dtau_per

  ! storage conventions:
  ! v = yt(2::pb%neqs)
  ! theta = yt(1::pb%neqs)
  ! sigma = yt(3::pb%neqs) if pb%neqs == 3
  ! dv/dt = dydt(2::pb%neqs)
  ! dtheta/dt = dydt(1::pb%neqs)
  ! dsigma/dt = dydt(3::pb%neqs) if pb%neqs == 3

  ! If pb%neqs == 3, then unpack sigma and dsigma_dt from yt and dydt
  ! else, obtain these values from pb%sigma and pb%dsigma_dt
  if ( pb%neqs == 3) then           ! Temp solution for normal stress coupling
    sigma = yt(3::pb%neqs)
    dsigma_dt = dydt(3::pb%neqs)
  else
    sigma = pb%sigma
    dsigma_dt = pb%dsigma_dt
  endif

  ! compute shear stress rate from elastic interactions, for 0D, 1D & 2D
  call compute_stress(pb%dtau_dt,dsigma_dt,pb%kernel,yt(2::pb%neqs)-pb%v_star)

  ! JPA Coulomb
  ! v = 0d0
  ! v(pb%rs_nodes) = yt(2::pb%neqs)
  !call compute_stress(pb%dtau_dt,pb%kernel,v-pb%v_star)

!YD we may want to modify this part later to be able to
!impose more complicated loading/pertubation
!functions involved: problem_class/problem_type; input/read_main
!                    initialize/init_field;  derivs_all/derivs
  ! periodic loading
  dtau_per = pb%Omper * pb%Aper * cos(pb%Omper*time)

  ! state evolution law, dtheta/dt = f(v,theta)
  dydt(1::pb%neqs) = dtheta_dt(yt(2::pb%neqs),yt(1::pb%neqs),pb)

  ! Time derivative of the elastic equilibrium equation
  !  dtau_load/dt + dtau_elastostatic/dt -impedance*dv/dt = sigma*( dmu/dv*dv/dt + dmu/dtheta*dtheta/dt )
  ! Rearranged in the following form:
  !  dv/dt = ( dtau_load/dt + dtau_elastostatic/dt - sigma*dmu/dtheta*dtheta/dt )/( sigma*dmu/dv + impedance )
  call dmu_dv_dtheta(dmu_dv,dmu_dtheta,yt(2::pb%neqs),yt(1::pb%neqs),pb)
  dydt(2::pb%neqs) = ( dtau_per + pb%dtau_dt - sigma*dmu_dtheta*dydt(1::pb%neqs) ) &
                   / ( sigma*dmu_dv + pb%zimpedance )

  ! Re-pack dsigma_dt in dydt or pb%dsigma_dt
  if ( pb%neqs == 3) then           ! Temp solution for normal stress coupling
   dydt(3::pb%neqs) = dsigma_dt
  else
   pb%dsigma_dt = dsigma_dt
  endif

end subroutine derivs

end module derivs_all
