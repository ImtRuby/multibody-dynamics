!=====================================================================!
! Parent class for integration schemes to extend. This has some common
! logic such as:
!
! (1) nonlinear solution process, 
! (2) approximating derivatives, 
! (3) writing solution to files.
!
! Author: Komahan Boopathy (komahan@gatech.edu)
!=====================================================================!

module integrator_class
  
  use iso_fortran_env, only : dp => real64
  use physics_class  , only : physics
  
  implicit none

  private
  public ::  integrator

  !===================================================================! 
  ! Abstract Integrator type
  !===================================================================! 

  type, abstract :: integrator
     
     !----------------------------------------------------------------!
     ! Contains the actual physical system
     !----------------------------------------------------------------!
     
     class(physics), pointer :: system => null()
     integer                 :: nsvars = 1 ! number of states/equations

     !----------------------------------------------------------------!
     ! Variables for managing time marching
     !----------------------------------------------------------------!

     integer  :: num_steps                     ! number of time steps
     real(dp) :: tinit = 0.0d0, tfinal = 1.0d0 ! initial and final times
     real(dp) :: h = 0.1d0                     ! default step size

     !----------------------------------------------------------------!
     ! Nonlinear solution at each stage
     !----------------------------------------------------------------!

     integer  :: max_newton = 25
     real(dp) :: atol = 1.0d-12, rtol = 1.0d-10

     !----------------------------------------------------------------!
     ! Track global time and states
     !----------------------------------------------------------------!

     real(dp), dimension(:), allocatable   :: time
     real(dp), dimension(:,:), allocatable :: U
     real(dp), dimension(:,:), allocatable :: UDOT
     real(dp), dimension(:,:), allocatable :: UDDOT

     !----------------------------------------------------------------!
     ! Miscellaneous variables
     !----------------------------------------------------------------!

     logical :: second_order = .false.
     logical :: forward = .true.
     integer :: print_level = 0
     integer :: current_step
     logical :: approximate_jacobian = .false.

   contains
     
     !----------------------------------------------------------------!
     ! Procedures                                                     !
     !----------------------------------------------------------------!

     procedure :: writeSolution
     procedure :: setPhysicalSystem
     procedure :: newtonSolve   
     procedure :: setPrintLevel
     procedure :: approximateJacobian

     !----------------------------------------------------------------!
     ! Important setters
     !----------------------------------------------------------------!
     
     procedure :: setApproximateJacobian

     !----------------------------------------------------------------!
     ! Adjoint Procedures                                                     !
     !----------------------------------------------------------------!

     procedure(InterfaceAssembleRHS), deferred :: assembleRHS
     procedure :: adjointSolve

  end type integrator

  interface
     
     !===================================================================!
     ! Interface routine to assemble the RHS of the adjoint systen
     !===================================================================!
     
     subroutine InterfaceAssembleRHS(this, rhs)
       
       use iso_fortran_env , only : dp => real64
       import integrator

       class(integrator)                     :: this
       real(dp), dimension(:), intent(inout) :: rhs

     end subroutine InterfaceAssembleRHS

  end interface

contains
  
  !===================================================================!
  ! Setter that can be used to set the method in which jacobian needs
  ! to be computed. Setting this to .true. would make the code use
  ! finite differences, this is enabled by default too. If set to
  ! .false. the expects to provide implementation in assembleJacobian
  ! in a type that extends PHYSICS.
  !===================================================================!
  
  subroutine setApproximateJacobian(this, approximateJacobian)

    class(integrator) :: this
    logical :: approximateJacobian

    this % approximate_jacobian = approximateJacobian

  end subroutine setApproximateJacobian

  !===================================================================!
  ! Set ANY physical system that extends the type PHYSICS and provides
  ! implementation to the mandatory functions assembleResidual and
  ! getInitialStates
  !===================================================================!
  
  subroutine setPhysicalSystem(this, physical_system)

    class(integrator)      :: this
    class(physics), target :: physical_system

    this % system => physical_system

  end subroutine setPhysicalSystem
  
  !===================================================================!
  ! Manages the amount of print
  !===================================================================!
  
  subroutine setPrintLevel(this,print_level)

    class(integrator) :: this
    integer           :: print_level

    this % print_level = print_level

  end subroutine setPrintLevel

  !===================================================================!
  ! Write solution to file
  !===================================================================!

  subroutine writeSolution(this, filename)
    
    class(integrator)                      :: this
    character(len=*), OPTIONAL, intent(in) :: filename
    character(len=7), parameter            :: directory = "output/"
    character(len=32)                      :: path = ""
    integer                                :: k, j, ierr
    
    path = trim(path)

    if (present(filename)) then
       path = directory//filename
    else
       path = directory//"solution.dat"
    end if
    
    open(unit=90, file=trim(path), iostat= ierr)
    
    if (ierr .ne. 0) then
       write(*,'("  >> Opening file ", 39A, " failed")') path
       return
    end if

    do k = 1, this % num_steps
       write(90, *)  this % time(k), (this % u(k,j), j=1,this%nsvars ), &
            & (this % udot(k,j), j=1,this%nsvars ), &
            & (this % uddot(k,j), j=1,this%nsvars )
    end do

    close(90)

  end subroutine writeSolution
  
  !===================================================================!
  ! Solve the nonlinear system at each step by driving the
  ! residual to zero
  !
  ! Input: 
  ! The guessed (initial) state variable values q, qdot, qddot are
  ! supplied
  !
  ! Output: q, qdot, qddot updated iteratively until the corresponding
  ! residual R = 0
  !
  ! alpha: multiplier for derivative of Residual wrt to q
  ! beta : multiplier for derivative of Residual wrt to qdot
  ! gamma: multiplier for derivative of Residual wrt to qddot
  !===================================================================!

  subroutine newtonSolve( this, alpha, beta, gamma, t, q, qdot, qddot )
    
    class(integrator)                     :: this

 ! Arguments
    real(dp), intent(in)                  :: alpha, beta, gamma
    real(dp), intent(in)                  :: t
    real(dp), intent(inout), dimension(:) :: q, qdot, qddot
    
 ! Lapack variables
    integer, allocatable, dimension(:)    :: ipiv
    integer                               ::  info, size
   
 ! Norms for tracking progress
    real(dp)                              :: abs_res_norm
    real(dp)                              :: rel_res_norm
    real(dp)                              :: init_norm
    
 ! Other Local variables
    real(dp), allocatable, dimension(:)   :: res, dq
    real(dp), allocatable, dimension(:,:) :: jac, fd_jac

    integer                               :: n, k
    logical                               :: conv = .false.

    real(dp)                              :: jac_err

    ! find the size of the linear system based on the calling object
    size = this % nsvars; k = this % current_step

    if ( .not. allocated(ipiv)   ) allocate( ipiv(size)        )
    if ( .not. allocated(res)    ) allocate( res(size)         )
    if ( .not. allocated(dq)     ) allocate( dq(size)          )
    if ( .not. allocated(jac)    ) allocate( jac(size,size)    )
    if ( .not. allocated(fd_jac) ) allocate( fd_jac(size,size) )

    if ( this % print_level .ge. 1 .and. k .eq. 2) then
       write(*,'(/2A5, 2A12/)') "Step", "Iter", "|R|", "|R|/|R1|"
    end if
    
    newton: do n = 1, this % max_newton

       ! Get the residual of the function
       call this % system % assembleResidual(res, t, q, qdot, qddot)

       ! Get the jacobian matrix
       if ( this % approximate_jacobian ) then
                    
          ! Compute an approximate Jacobian using finite differences
          call this % approximateJacobian(jac, alpha, beta, gamma, t, q, qdot, qddot)

       else
          
          ! Use the user supplied Jacobian implementation
          call this % system % assembleJacobian(jac, alpha, beta, gamma, t, q, qdot, qddot)
          
          ! Check the Jacobian implementation once at the beginning of integration
          if ( k .eq. 2 .and. n .eq. 1 ) then
             
             ! Compute an approximate Jacobian using finite differences
             call this % approximateJacobian(fd_jac, alpha, beta, gamma, t, q, qdot, qddot)

             ! Compare the exact and approximate Jacobians and
             ! complain about the error in Jacobian if there is any
             jac_err = maxval(abs(fd_jac - jac))
             if ( jac_err .gt. 1.0d-6) then
                print *, "q     =", q
                print *, "qdot  =", qdot
                print *, "qddot =", qddot
                print *, "a,b,c =", alpha, beta, gamma
                print *, "J     =", jac
                print *, "Jhat  =", fd_jac
                print *, "WARNING: Possible error in jacobian", jac_err
             end if
             
          end if

       end if
       
       ! Find norm of the residual
       abs_res_norm = norm2(res)
       if ( n .eq. 1) init_norm = abs_res_norm
       rel_res_norm = abs_res_norm/init_norm

       if ( this % print_level .eq. 2) then
          write(*, "(2I5,2ES12.2)") k, n, abs_res_norm, rel_res_norm
       end if

       ! Check stopping
       if ((abs_res_norm .le. this % atol) .or. (rel_res_norm .le. this % rtol)) then
          conv = .true.
          exit newton
       else if (abs_res_norm .ne. abs_res_norm .or. rel_res_norm .ne. rel_res_norm ) then
          conv = .false.
          exit newton
       end if

       ! Call LAPACK to solve the stage values system
       dq = -res
       call DGESV(size, 1, jac, size, IPIV, dq, size, INFO)
       
       ! Update the solution
       qddot = qddot + gamma * dq
       qdot  = qdot  + beta  * dq
       q     = q     + alpha * dq
       
    end do newton

    if (this % print_level .eq. 1) then 
       write(*, "(2I5,2ES12.2)") k, n, abs_res_norm, rel_res_norm
    end if

    ! Print warning message if not converged
    if (.not. conv) then
       write(*,'(/2A5, 2A12)') "STEP", "ITER", "|R|", "|R|/|R1|"
       write(*, "(2I5,2ES12.2)") k, n, abs_res_norm, rel_res_norm
       stop "Newton Solve Failed"
    end if

    if (allocated(ipiv)) deallocate(ipiv)
    if (allocated(res)) deallocate(res)
    if (allocated(dq)) deallocate(dq)
    if (allocated(jac)) deallocate(jac)
    if (allocated(fd_jac)) deallocate(fd_jac)
            
  end subroutine newtonSolve

  !===================================================================! 
  ! Routine that approximates the Jacobian based on finite differences
  ! [d{R}/d{q}] = alpha*[dR/dq] + beta*[dR/dqdot] + gamma*[dR/dqddot]
  !===================================================================!
  
  subroutine approximateJacobian( this, jac, alpha, beta, gamma, t, q, qdot, qddot )

    class(integrator)                       :: this
    
    ! Matrices
    real(dp), intent(inout), dimension(:,:) :: jac
    
    ! Arrays
    real(dp), intent(in)                    :: t
    real(dp), intent(in), dimension(:)      :: q, qdot, qddot     ! states

    real(dp), allocatable, dimension(:)     :: pstate             ! perturbed states
    real(dp), allocatable, dimension(:)     :: R, Rtmp            ! original residual and perturbed residual

    ! Scalars
    real(dp)                                :: dh = 1.0d-6        ! finite-diff step size
    real(dp), intent(in)                    :: alpha, beta, gamma ! linearization coefficients
    integer                                 :: m                  ! loop variables

    !  Zero the supplied jacobian matrix for safety (as we are
    !  computing everything newly here)
    jac = 0.0d0
    
    ! Allocate required arrays
    allocate(pstate(this % nsvars)); pstate = 0.0d0;
    allocate(R(this % nsvars));      R = 0.0d0;
    allocate(Rtmp(this % nsvars));   Rtmp = 0.0d0;

    ! Make a residual call with original variables
    call this % system % assembleResidual(R, t, q, qdot, qddot)

    !-----------------------------------------------------------!
    ! Derivative of R WRT Q: dR/dQ
    !-----------------------------------------------------------!

    pstate = q

    loop_vars: do m = 1, this % nsvars

       ! Perturb the k-th variable
       pstate(m) = pstate(m) + dh

       ! Make a residual call with the perturbed variable
       call this % system % assembleResidual(Rtmp, t, pstate, qdot, qddot)

       ! Unperturb (restore) the k-th variable
       pstate(m) =  q(m)

       ! Approximate the jacobian with respect to the k-th variable
       jac(:,m) = jac(:,m) + alpha*(Rtmp-R)/dh

    end do loop_vars

    !-----------------------------------------------------------!
    ! Derivative of R WRT QDOT: dR/dQDOT
    !-----------------------------------------------------------!

    pstate = qdot

    do m = 1, this % nsvars

       ! Perturb the k-th variable
       pstate(m) = pstate(m) + dh

       ! Make a residual call with the perturbed variable
       call this % system % assembleResidual(Rtmp, t, q, pstate, qddot)

       ! Unperturb (restore) the k-th variable
       pstate(m) =  qdot(m)

       ! Approximate the jacobian with respect to the k-th variable
       Jac(:,m) = Jac(:,m) + beta*(Rtmp-R)/dh

    end do

    ! Second order equations have an extra block to add
    if (this % second_order) then

       !-----------------------------------------------------------!
       ! Derivative of R WRT QDDOT: dR/dQDDOT
       !-----------------------------------------------------------!     

       pstate = qddot

       do m = 1, this % nsvars

          ! Perturb the k-th variable
          pstate(m) = pstate(m) + dh

          ! Make a residual call with the perturbed variable
          call this % system % assembleResidual(Rtmp, t, q, qdot, pstate)

          ! Unperturb (restore) the k-th variable
          pstate(m) =  qddot(m)

          ! Approximate the jacobian with respect to the k-th variable
          Jac(:,m) = Jac(:,m) + gamma*(Rtmp-R)/dh

       end do

    end if ! first or second order

    deallocate(pstate)
    deallocate(R,Rtmp)

  end subroutine approximateJacobian

  !====================================================================!
  ! Common routine to solve the adjoint linear system at each time
  ! step and/or stage
  !=====================================================================!
  
  subroutine adjointSolve(this, psi, alpha, beta, gamma, t, q, qdot, qddot)
    
    class(integrator) :: this

 ! Arguments
    real(dp), intent(in)                  :: alpha, beta, gamma
    real(dp), intent(in)                  :: t
    real(dp), intent(inout), dimension(:) :: q, qdot, qddot
    real(dp), intent(inout), dimension(:) :: psi

 ! Lapack variables
    integer, allocatable, dimension(:)    :: ipiv
    integer                               :: info, size
       
 ! Other Local variables
    real(dp), allocatable, dimension(:)   :: rhs
    real(dp), allocatable, dimension(:,:) :: jac

    ! find the size of the linear system based on the calling object
    size = this % nsvars
    
    if (.not.allocated(ipiv)) allocate(ipiv(size))
    if (.not.allocated(rhs)) allocate(rhs(size))
    if (.not.allocated(jac)) allocate(jac(size,size))

    ! Assemble the residual of the function
    call this % assembleRHS(rhs)

    ! Assemble the jacobian matrix
    call this % system % assembleJacobian(jac, alpha, beta, gamma, t, q, qdot, qddot)

    ! Transpose the system
    jac = transpose(jac)
    
    ! Call lapack to solve the stage values system
    call DGESV(size, 1, jac, size, IPIV, rhs, size, INFO)

    ! Store into the output array
    psi = rhs
    
    if (allocated(ipiv)) deallocate(ipiv)
    if (allocated(rhs)) deallocate(rhs)
    if (allocated(jac)) deallocate(jac)
    
  end subroutine adjointSolve

end module integrator_class
