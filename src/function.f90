!=====================================================================!
! Module that contains common procedures for any function of interest
! that the user wishes to implement.

! If the physical system modeled is dynamics, one might be interested
! in creating the kinetic energy as a function
!
! If a fluid dynamics system is modeled as the physics, lift, drag,
! l/d might be the functions of interest that shall be modeled using
! this abstract class
!
! In structures one might be interested in quantities such as strain,
! stress etc
!
! Author: Komahan Boopathy (komahan@gatech.edu)
! =====================================================================!

module function_class

  implicit none

  private
  public :: abstract_function

  !-------------------------------------------------------------------!
  ! Type that models any funtion of interest e.g. kinetic energy, lift
  !-------------------------------------------------------------------!
  
  type, abstract :: abstract_function
    
   contains

     procedure(interface_evaluate), deferred :: getFunctionValue ! function value at t, X, U, Udot, Uddot
     procedure(interface_gradient), deferred :: addDFdX          ! partial derivative
     procedure(interface_gradient), deferred :: addDFdU          ! partial derivative
     procedure(interface_gradient), deferred :: addDFdUDot       ! partial derivative
     procedure(interface_gradient), deferred :: addDFdUDDot      ! partial derivative

  end type abstract_function

  abstract interface

     !----------------------------------------------------------------!
     ! Interface for evaluating the function for t, U, Udot, Uddot
     !----------------------------------------------------------------!

     subroutine interface_evaluate(this, f, time, x, u, udot, uddot)

       import abstract_function

       class(abstract_function)             :: this
       real(8), intent(inout), dimension(:) :: f
       real(8), intent(in)                  :: time
       real(8), intent(in), dimension(:)    :: x, u, udot, uddot
       
     end subroutine interface_evaluate

     !----------------------------------------------------------------!
     ! Interface for evaluating the gradient for t, x, U, Udot, Uddot
     !----------------------------------------------------------------!
     
     subroutine interface_gradient(this, res, scale, time, x, u, udot, uddot)

       import abstract_function

       class(abstract_function)             :: this
       real(8), intent(inout), dimension(:) :: res
       real(8), intent(in)                  :: time
       real(8), intent(in), dimension(:)    :: x, u, udot, uddot
       real(8)                              :: scale

     end subroutine interface_gradient

  end interface
  
end module function_class