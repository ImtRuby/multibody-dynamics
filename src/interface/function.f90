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
     procedure(interface_evaluate), deferred :: getdFdX          ! partial derivative
     procedure(interface_evaluate), deferred :: getdFdU          ! partial derivative
     procedure(interface_evaluate), deferred :: getdFdUDot       ! partial derivative
     procedure(interface_evaluate), deferred :: getdFdUDDot      ! partial derivative

  end type abstract_function

  interface

     !----------------------------------------------------------------!
     ! Interface for evaluating the function for t, X, U, Udot, Uddot
     !----------------------------------------------------------------!

     subroutine interface_evaluate(this, res, time, x, u, udot, uddot)

       import abstract_function

       class(abstract_function) :: this
       real(8), intent(inout), dimension(:) :: res
       real(8), intent(in) :: time
       real(8), intent(in), dimension(:) :: x, u, udot, uddot
       
     end subroutine interface_evaluate

  end interface
  
end module function_class
