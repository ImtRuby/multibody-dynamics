!=====================================================================!
! Module that contains functions related to spring mass damper system
!
! Author: Komahan Boopathy (komahan@gatech.edu)
!=====================================================================!

module oscillator_functions_class

  use iso_fortran_env, only : dp => real64
  use function_class, only  : abstract_function

  implicit none

  private
  public :: pitch

  !-------------------------------------------------------------------!
  ! Type that models any physical phenomenon
  !-------------------------------------------------------------------!
  
  type, extends(abstract_function) :: pitch

   contains  

     procedure :: getFunctionValue ! function value at t, X, U, Udot, Uddot
     procedure :: addDFdX          ! partial derivative
     procedure :: addDFdU          ! partial derivative
     procedure :: addDFdUDot       ! partial derivative
     procedure :: addDFdUDDot      ! partial derivative

  end type pitch

contains

  !-------------------------------------------------------------------!
  ! Evaluate the pitch of the airfoil
  ! -------------------------------------------------------------------!
  
  pure subroutine getFunctionValue(this, f, time, x, u, udot, uddot)
    
    class(pitch), intent(inout)       :: this
    real(8), intent(inout)            :: f
    real(8), intent(in)               :: time
    real(8), intent(in), dimension(:) :: x, u, udot, uddot
    
    f = abs(u(2))
    
  end subroutine getFunctionValue

  !-------------------------------------------------------------------!
  ! Evaluate  dF/dX
  !-------------------------------------------------------------------!

  subroutine addDfdX(this, res, scale, time, x, u, udot, uddot)

    class(pitch)                         :: this
    real(8), intent(inout), dimension(:) :: res
    real(8), intent(in)                  :: time
    real(8), intent(in), dimension(:)    :: x, u, udot, uddot
    real(8)                              :: scale
    
   res = 0.0d0

  end subroutine addDfdX
  
  !-------------------------------------------------------------------!
  ! Evaluate  dF/dU
  ! -------------------------------------------------------------------!

  subroutine addDfdU(this, res, scale, time, x, u, udot, uddot)

    class(pitch)                :: this
    real(8), intent(inout), dimension(:) :: res
    real(8), intent(in)                  :: time
    real(8), intent(in), dimension(:)    :: x, u, udot, uddot
    real(8)                              :: scale

    res(1) = res(1) + scale*0.0d0
    res(2) = res(2) + scale*sign(1.0d0,u(2))
    
  end subroutine addDfdU

  !-------------------------------------------------------------------!
  ! Evaluate  dF/dUdot
  ! -------------------------------------------------------------------!

  subroutine addDfdUDot(this, res, scale, time, x, u, udot, uddot)

    class(pitch)                :: this
    real(8), intent(inout), dimension(:) :: res
    real(8), intent(in)                  :: time
    real(8), intent(in), dimension(:)    :: x, u, udot, uddot
    real(8)                              :: scale
    
    res(1) = res(1) + scale*0.0d0 ! wrt to udot(1)

  end subroutine addDFdUDot
  
  !-------------------------------------------------------------------!
  ! Evaluate  dF/dUDDot
  ! -------------------------------------------------------------------!

  subroutine addDfdUDDot(this, res, scale, time, x, u, udot, uddot)

    class(pitch)                :: this
    real(8), intent(inout), dimension(:) :: res
    real(8), intent(in)                  :: time
    real(8), intent(in), dimension(:)    :: x, u, udot, uddot
    real(8)                              :: scale

    res(1) = res(1) + scale*0.0d0 ! wrt to uddot(1)

  end subroutine addDfdUDDot

end module oscillator_functions_class