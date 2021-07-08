      !
      !
      ! This file contains the core subroutines for working with the
      ! discrete Lehmann representation
      !
      !


      !> Set parameters for composite Chebyshev fine grid
      !! @param[in] lambda cutoff parameter
      !! @param[out] p Chebyshev degree in each subinterval
      !! @param[out] npt # subintervals on [0,1/2] in tau space (#
      !!  subintervals on [0,1] is 2*npt
      !! @param[out] npo # subintervals on [0,lambda] in omega space
      !!  subintervals on [-lambda,lambda] is 2*npo)
      !! @param[out] nt # fine grid points in tau = 2*npt*p
      !! @param[out] no # fine grid points in omega = 2*npo*p

      subroutine gridparams(lambda,p,npt,npo,nt,no)

      ! Input:
      !
      ! lambda  - cutoff parameter
      !
      ! Output:
      !
      ! p       - Chebyshev degree in each subinterval
      ! npt     - # subintervals on [0,1/2] in tau space (# subintervals
      !             on [0,1] is 2*npt)
      ! npo     - # subintervals on [0,lambda] in omega space (#
      !             subintervals on [-lambda,lambda] is 2*npo)
      ! nt      - # fine grid points in tau = 2*npt*p
      ! no      - # fine grid points in omega = 2*npo*p

      implicit none
      integer p,npt,npo,nt,no
      real *8 lambda

      p = 24 ! Chebyshev degree of panels
      
      npt = max(ceiling(log(lambda)/log(2.0d0))-2,1)
      npo = max(ceiling(log(lambda)/log(2.0d0)),1)

      nt = 2*p*npt
      no = 2*p*npo

      end subroutine gridparams


      !> Discretization of kernel K(tau,omega) on composite Chebyshev
      !! fine grids in tau and omega
      !! @param[in] lambda cutoff parameter
      !! @param[in] p Chebyshev degree in each subinterval
      !! @param[in] npt # subintervals on [0,1/2] in tau space (#
      !!  subintervals on [0,1] is 2*npt)
      !! @param[in] npo # subintervals on [0,lambda] in omega space
      !!  subintervals on [-lambda,lambda] is 2*npo)
      !! @param[out] t tau fine grid points on (0,1/2) (half of full grid)
      !! @param[out] om omega fine grid points
      !! @param[out] kmat K(tau,omega) on fine grid
      !! @param[out] om omega fine grid points
      !! @param[out] err Error of composite Chebyshev interpolant of
      !!  K(tau,omega). err(1) is ~= max relative L^inf error
      !!  in tau over all omega in fine grid. err(2) is ~= max
      !!  L^inf error in omega over all tau in fine grid.

      subroutine kfine_cc(lambda,p,npt,npo,t,om,kmat,err)

      ! Discretization of kernel K(tau,omega) on composite Chebyshev
      ! fine grids in tau and omega
      !
      ! Input:
      !
      ! lambda  - cutoff parameter
      ! p       - Chebyshev degree in each subinterval
      ! npt     - # subintervals on [0,1/2] in tau space (# subintervals
      !             on [0,1] is 2*npt)
      ! npo     - # subintervals on [0,lambda] in omega space (#
      !             subintervals on [-lambda,lambda] is 2*npo)
      !
      ! Output:
      !
      ! t       - tau fine grid points on (0,1/2) (half of full grid)
      ! om      - omega fine grid points
      ! kmat    - K(tau,omega) on fine grid 
      ! err     - Error of composite Chebyshev interpolant of
      !             K(tau,omega). err(1) is ~= max relative L^inf error
      !             in tau over all omega in fine grid. err(2) is ~= max
      !             L^inf error in omega over all tau in fine grid.

      implicit none
      integer p,npt,npo
      real *8 lambda,t(npt*p),om(2*npo*p)
      real *8 kmat(2*npt*p,2*npo*p),err(2)
      real *8, external :: kfunf

      integer nt,no,i,j,k
      real *8 one,a,b,start,finish,xx,ktrue,ktest,errtmp
      real *8, allocatable :: xc(:),wc(:),pbpt(:),pbpo(:)
      real *8, allocatable :: ktcoef(:,:),komcoef(:,:)
      real *8, allocatable :: xc2(:),wc2(:)

      one = 1.0d0

      nt = 2*npt*p
      no = 2*npo*p

      ! --- Chebyshev nodes and interpolation weights ---

      allocate(xc(p),wc(p))
      
      call barychebinit(p,xc,wc)

      ! -- Tau space discretization ---

      ! Panel break points

      allocate(pbpt(2*npt+1))

      pbpt(1) = 0*one
      do i=1,npt
        pbpt(i+1) = one/2**(npt-i+1)
      enddo

      !pbpt(npt+2:2*npt+1) = 1-pbpt(npt:1:-1)

      ! Grid points

      do i=1,npt
        a = pbpt(i)
        b = pbpt(i+1)
        t((i-1)*p+1:i*p) = a + (b-a)*(xc+one)/2
      enddo

      ! --- Omega space discretization ---

      ! Panel break points

      allocate(pbpo(2*npo+1))

      pbpo(npo+1) = 0*one
      do i=1,npo
        pbpo(npo+i+1) = lambda/2**(npo-i)
      enddo

      pbpo(1:npo) = -pbpo(2*npo+1:npo+2:-1)

      ! Grid points

      do i=1,2*npo
        a = pbpo(i)
        b = pbpo(i+1)
        om((i-1)*p+1:i*p) = a + (b-a)*(xc+one)/2
      enddo

      ! --- Sample K(tau,omega) on grid ---

      do j=1,no
        do i=1,nt/2

          kmat(i,j) = kfunf(t(i),om(j))

        enddo
      enddo

      ! Copy second half of matrix from first half to improve accuracy
      ! for extremely large npt: computing exp((1-t)*omega) loses digits
      ! if t is very close to 1 and (1-t)*omega ~ 1, but exp(-omega*t)
      ! is fine for small t and t*omega ~ 1.

      kmat(nt/2+1:nt,1:no) = kmat(nt/2:1:-1,no:1:-1)


      ! --- Check accuracy of Cheb interpolant on each panel in tau
      ! for fixed omega, and each panel in omega for fixed tau, by
      ! comparing with K(tau,omega) on Cheb grid of 2*p nodes ---

      allocate(xc2(2*p),wc2(2*p))

      call barychebinit(2*p,xc2,wc2)

      err(:) = 0.0d0

      do j=1,no

        errtmp = 0.0d0

        do i=1,npt
          
          a = pbpt(i)
          b = pbpt(i+1)

          do k=1,2*p

            xx = a+(b-a)*(xc2(k)+one)/2
            
            ktrue = kfunf(xx,om(j))

            call barycheb(p,xc2(k),kmat((i-1)*p+1:i*p,j),wc,xc,ktest)

            errtmp = max(errtmp,abs(ktrue-ktest))

          enddo
        enddo

        err(1) = max(err(1),errtmp/maxval(kmat(:,j)))

      enddo


      do j=1,nt/2

        errtmp = 0.0d0

        do i=1,2*npo
          
          a = pbpo(i)
          b = pbpo(i+1)

          do k=1,2*p

            xx = a+(b-a)*(xc2(k)+one)/2
            
            ktrue = kfunf(t(j),xx)

            call barycheb(p,xc2(k),kmat(j,(i-1)*p+1:i*p),wc,xc,ktest)

            errtmp = max(errtmp,abs(ktrue-ktest))

          enddo
        enddo

        err(2) = max(err(2),errtmp/maxval(kmat(j,:)))

      enddo


      end subroutine kfine_cc


      
      subroutine dlr_rf(lambda,eps,nt,no,om,kmat,rank,dlrrf,oidx)

      ! Select real frequency nodes defining DLR basis
      !
      ! Input:
      !
      ! lambda  - cutoff parameter
      ! eps     - DLR error tolerance
      ! nt      - # fine grid points in tau
      ! no      - # fine grid points in omega
      ! om      - omega fine grid points
      ! kmat    - K(tau,omega) on fine grid
      ! rank    - max possible rank of DLR, defining input size of some
      !             arrays
      !
      ! Output :
      !
      ! rank    - rank of DLR (# basis functions)
      ! dlrrf   - selected real frequency nodes (omega points)
      ! oidx    - column indices of kmat corresponding to selected real
      !             frequency nodes

      implicit none
      integer nt,no,rank,oidx(rank)
      real *8 lambda,eps,om(no),kmat(nt,no),dlrrf(rank)

      integer, allocatable :: list(:)
      real *8, allocatable :: tmp(:,:),work(:)

      ! --- Select real frequency nodes by pivoted QR on columns of 
      ! kmat ---

      allocate(tmp(nt,no),list(no),work(max(nt,no)))

      tmp = kmat

      ! Pivoted QR 
      
      call iddp_qrpiv(eps,nt,no,tmp,rank,list,work)

      ! Rearrange indices to get selected frequency point indices

      call ind_rearrange(no,rank,list)

      ! Extract selected frequencies

      oidx(1:rank) = list(1:rank)
      dlrrf(1:rank) = om(oidx(1:rank))
          
      end subroutine dlr_rf


      subroutine dlr_it(lambda,nt,no,t,kmat,rank,oidx,dlrit)

      ! Select imaginary time DLR nodes
      !
      ! Input:
      !
      ! lambda  - cutoff parameter
      ! nt      - # fine grid points in tau
      ! no      - # fine grid points in omega
      ! t       - tau fine grid points
      ! kmat    - K(tau,omega) on fine grid
      ! rank    - rank of DLR (# basis functions)
      ! oidx    - column indices of kmat corresponding to selected real
      !             frequency nodes
      !
      ! Output :
      !
      ! dlrit   - selected imaginary time nodes (tau points)

      implicit none
      integer nt,no,rank,oidx(rank)
      real *8 lambda,t(nt),kmat(nt,no),dlrit(rank)

      integer j,k
      integer, allocatable :: list(:),tidx(:)
      real *8, allocatable :: tmp(:,:),work(:)

      ! --- Select imaginary time nodes by pivoted QR on rows of 
      ! kmat ---

      ! Matrix of selected columns

      allocate(tmp(rank,nt),list(nt),work(nt),tidx(rank))

      do j=1,nt
        do k=1,rank
          tmp(k,j) = kmat(j,oidx(k))
        enddo
      enddo

      ! Pivoted QR

      call iddr_qrpiv(rank,nt,tmp,rank,list,work)

      ! Rearrange indices to get selected imaginary time node indices

      call ind_rearrange(nt,rank,list)

      ! Extract selected imaginary times. To maintain high precision for
      ! extremely large lambda and small eps calculations, if t was
      ! chosen which is close to 1, take the calculated value t*=1-t,
      ! which is known to full relative precision, and store -t*. Then t
      ! can either be recovered as 1+(-t*), resulting in a loss of
      ! relative precision, or we can use the high relative precision
      ! value directly if we have access to a high accuracy close-to-1
      ! evaluator.

      tidx = list(1:rank)

      do j=1,rank
        if (tidx(j).le.nt/2) then
          dlrit(j) = t(tidx(j))
        else
          dlrit(j) = -t(nt-tidx(j)+1)
        endif
      enddo
      
      end subroutine dlr_it


      subroutine dlr_cf2it(rank,dlrrf,dlrit,cf2it)

      ! Build transform matrix from DLR coefficients to samples on
      ! imaginary time grid. To obtain the samples of a DLR expansion on
      ! the imaginary time grid, apply the matrix cf2it to the vector of
      ! DLR coefficients.
      !
      ! Input:
      !
      ! rank  - rank of DLR (# basis functions)
      ! dlrrf   - selected real frequency nodes (omega points)
      ! dlrit   - selected imaginary time nodes (tau points)
      !
      ! Output :
      !
      ! cf2it - DLR coefficients -> imaginary time grid values transform
      !           matrix


      implicit none
      integer rank
      real *8 dlrrf(rank),dlrit(rank),cf2it(rank,rank)

      integer j,k
      real *8, external :: kfunf_rel

      ! Get the matrix K(tau_j,omega_k)

      do k=1,rank
        do j=1,rank
          cf2it(j,k) = kfunf_rel(dlrit(j),dlrrf(k))
        enddo
      enddo

      end subroutine dlr_cf2it


      subroutine dlr_it2cf(rank,dlrrf,dlrit,it2cf,it2cfpiv)

      ! Build transform matrix from samples on imaginary time grid to
      ! DLR coefficients, stored in LU form. To obtain the coefficients
      ! of a DLR expansion from samples on the imaginary time grid, use
      ! the outputs of this subroutine in conjunction with the dlr_expnd
      ! subroutine.
      !
      ! Input:
      !
      ! rank      - rank of DLR (# basis functions)
      ! dlrrf   - selected real frequency nodes (omega points)
      ! dlrit   - selected imaginary time nodes (tau points)
      !
      ! Output :
      !
      ! it2cf     - imaginary time grid values -> DLR coefficients
      !               transform matrix in lapack LU storage format
      ! it2cfpiv  - pivot matrix for it2cf in lapack LU storage format


      implicit none
      integer rank,it2cfpiv(rank)
      real *8 dlrrf(rank),dlrit(rank),it2cf(rank,rank)

      integer j,k,info
      real *8, external :: kfunf_rel

      ! Get the matrix K(tau_j,omega_k)

      do k=1,rank
        do j=1,rank
          it2cf(j,k) = kfunf_rel(dlrit(j),dlrrf(k))
        enddo
      enddo

      ! LU factorize

      call dgetrf(rank,rank,it2cf,rank,it2cfpiv,info)

      end subroutine dlr_it2cf


      subroutine dlr_it2itr(rank,dlrrf,dlrit,it2cf,it2cfpiv,it2itr)

      ! Build matrix taking values of G(tau) at imaginary time DLR nodes
      ! to values of G(beta-tau) at imaginary time DLR nodes, or
      ! equivalently, at "reversed" DLR imaginary time nodes.
      !
      ! Input:
      !
      ! rank      - rank of DLR (# basis functions)
      ! dlrrf     - selected real frequency nodes (omega points)
      ! dlrit     - selected imaginary time nodes (tau points)
      ! it2cf     - imaginary time grid values -> DLR coefficients
      !               transform matrix in lapack LU storage format
      ! it2cfpiv  - pivot matrix for it2cf in lapack LU storage format
      !
      ! Output :
      !
      ! it2itr    - Matrix taking vector of G(tau) values to G(beta-tau)
      !               values at imaginary time DLR nodes

      implicit none
      integer rank,it2cfpiv(rank)
      real *8 dlrrf(rank),dlrit(rank),it2cf(rank,rank),it2itr(rank,rank)

      integer i,j,info
      real *8, external :: kfunf_rel

      ! Get matrix taking DLR coefficients to values of DLR expansion at
      ! imaginary time nodes reflected about tau = beta/2.

      do j=1,rank
        do i=1,rank
          it2itr(i,j) = kfunf_rel(-dlrit(i),dlrrf(j))
        enddo
      enddo

      ! Precompose with matrix taking DLR imaginary time grid values ->
      ! DLR coefficients

      it2itr = transpose(it2itr)

      call dgetrs('T',rank,rank,it2cf,rank,it2cfpiv,it2itr,rank,info)

      it2itr = transpose(it2itr)

      end subroutine dlr_it2itr


      subroutine dlr_expnd(rank,it2cf,it2cfpiv,g,gc)
      
      ! Get coefficients of DLR from samples on imaginary time DLR grid
      !
      ! Input:
      !
      ! rank      - rank of DLR (# basis functions)
      ! it2cf     - imaginary time grid values -> DLR coefficients
      !               transform matrix in lapack LU storage format
      ! it2cfpiv  - pivot matrix for it2cf in lapack LU storage format
      ! g         - Samples of a function G at imaginary time grid
      !               points
      !
      ! Output :
      !
      ! gc        - DLR coefficients of G
      
      implicit none
      integer rank,it2cfpiv(rank)
      real *8 it2cf(rank,rank),g(rank),gc(rank)

      integer info

      ! Backsolve with imaginary time grid values -> DLR coefficients
      ! transform matrix stored in LU form

      gc = g

      call dgetrs('N',rank,1,it2cf,rank,it2cfpiv,gc,rank,info)

      end subroutine dlr_expnd



      subroutine dlr_mfexpnd(rank,mf2cf,mf2cfpiv,g,gc)

      ! Get coefficients of DLR from samples on Matsubara frequency DLR
      ! grid
      !
      ! Input:
      !
      ! rank      - rank of DLR (# basis functions)
      ! mf2cf     - Matsubara frequency grid values -> DLR coefficients
      !               transform matrix in lapack LU storage format
      ! mf2cfpiv  - pivot matrix for mf2cf in lapack LU storage format
      ! g         - Samples of a function G at Matsubara frequency grid
      !               points
      !
      ! Output :
      !
      ! gc        - DLR coefficients of G

      implicit none
      integer rank,mf2cfpiv(rank)
      real *8 gc(rank)
      complex *16 mf2cf(rank,rank),g(rank)

      integer info
      complex *16, allocatable :: tmp(:)

      ! Backsolve with DLR transform matrix in factored form

      allocate(tmp(rank))

      tmp = g

      call zgetrs('N',rank,1,mf2cf,rank,mf2cfpiv,tmp,rank,info)

      gc = real(tmp)

      end subroutine dlr_mfexpnd


      subroutine dlr_eval(rank,dlrrf,g,t,val)

      ! Evaluate DLR expansion at a point t
      !
      ! Input:
      !
      ! rank    - rank of DLR (# basis functions)
      ! dlrrf   - selected real frequency nodes (omega points)
      ! g       - DLR coefficients of a function G
      ! t       - evaluation points in t' format
      !
      ! Output:
      !
      ! val     - value of DLR of G at t
      !
      ! Note: to evaluate at a point 0.5<t<1, input the value t' = t-1.
      ! If t' has been computed to high relative precision, this
      ! subroutine will avoid loss of digits for t very close to 1 by
      ! evaluating the kernel K using its symmetries.

      implicit none
      integer rank
      real *8 dlrrf(rank),g(rank),t,val

      integer i
      real *8 kval
      real *8, external :: kfunf

      val = 0.0d0
      do i=1,rank

        ! For 0.5<t<1, corresponding to negative t', use symmetry of K
        ! to evaluate basis functions

        if (t.ge.0.0d0) then
          kval = kfunf(t,dlrrf(i))
        else
          kval = kfunf(-t,-dlrrf(i))
        endif

        val = val + g(i)*kval

      enddo

      end subroutine dlr_eval



      subroutine dlr_mf_eval(rank,dlrrf,g,n,val)

      ! Evaluate DLR expansion at a point t
      !
      ! Input:
      !
      ! rank    - rank of DLR (# basis functions)
      ! dlrrf   - selected real frequency nodes (omega points)
      ! g       - DLR coefficients of a function G
      ! n       - evaluation point in Matsubara frequency
      !
      ! Output:
      !
      ! val     - value of DLR of G at n

      implicit none
      integer rank,n
      real *8 dlrrf(rank),g(rank)
      complex *16 val

      integer i
      complex *16 kval
      complex *16, external :: kfunf_mf

      val = 0.0d0
      do i=1,rank

        kval = kfunf_mf(n,dlrrf(i))

        val = val + g(i)*kval

      enddo

      end subroutine dlr_mf_eval


      subroutine dlr_mf(nmax,rank,dlrrf,dlrmf)

      ! Select Matsubara frequency DLR nodes
      !      
      ! Input:
      !
      ! nmax    - Matsubara frequency cutoff
      ! rank    - rank of DLR (# basis functions)
      ! dlrrf   - selected real frequency nodes (omega points)
      !
      ! Output :
      !
      ! dlrmf   - selected Matsubara frequency nodes

      implicit none
      integer nmax,rank,dlrmf(rank)
      real *8 dlrrf(rank)

      integer i,k,info
      integer, allocatable :: ns(:),list(:)
      real *8, allocatable :: work(:)
      complex *16, allocatable :: poles(:,:)
      complex *16, external :: kfunf_mf

      ! Get matrix of Fourier transforms of DLR basis functions

      allocate(poles(rank,2*nmax+1),ns(2*nmax+1))

      ns = (/(i, i=-nmax,nmax)/)

      do i=1,2*nmax+1
        do k=1,rank
          
          poles(k,i) = kfunf_mf(ns(i),dlrrf(k))
          
        enddo
      enddo

      ! --- Select Matsubara frequency nodes by pivoted QR on rows of
      ! Fourier transformed K matrix ---

      allocate(list(2*nmax+1),work(2*nmax+1))

      ! Pivoted QR

      call idzr_qrpiv(rank,2*nmax+1,poles,rank,list,work)

      ! Rearrange indices to get selected frequency point indices

      call ind_rearrange(2*nmax+1,rank,list)

      ! Extract selected frequencies

      dlrmf = ns(list(1:rank))

      end subroutine dlr_mf


      subroutine dlr_mf2cf(nmax,rank,dlrrf,dlrmf,mf2cf,mf2cfpiv)

      ! Build transform matrix from samples on Matsubara frequency grid
      ! to DLR coefficients in LU form
      !
      ! Input:
      !
      ! nmax    - Matsubara frequency cutoff
      ! rank    - rank of DLR (# basis functions)
      ! dlrrf   - selected real frequency nodes (omega points)
      ! dlrmf   - selected Matsubara frequency nodes
      !
      ! Output :
      !
      ! mf2cf   - Matsubara frequency grid values -> DLR coefficients
      !               transform matrix in lapack LU storage format
      ! mf2cfpiv  - pivot matrix for mf2cf in lapack LU storage format

      implicit none
      integer nmax,rank,dlrmf(rank),mf2cfpiv(rank)
      real *8 dlrrf(rank)
      complex *16 mf2cf(rank,rank)

      integer j,k,info
      complex *16, external :: kfunf_mf

      ! Extract selected rows and columns of Fourier transformed K
      ! matrix

      do k=1,rank
        do j=1,rank
          mf2cf(j,k) = kfunf_mf(dlrmf(j),dlrrf(k))
        enddo
      enddo

      ! LU factorize

      call zgetrf(rank,rank,mf2cf,rank,mf2cfpiv,info)

      end subroutine dlr_mf2cf


      subroutine dlr_cf2mf(rank,dlrrf,dlrmf,cf2mf)

      ! Build transform matrix from DLR coefficients to samples on
      ! Matsubara frequency grid. To obtain the samples of a DLR
      ! expansion on the Matsubara frequency grid, apply the matrix
      ! cf2mf to the vector of DLR coefficients.
      !
      ! Input:
      !
      ! rank  - rank of DLR (# basis functions)
      ! dlrrf - selected real frequency nodes (omega points)
      ! dlrmf - selected Matsubara frequency nodes
      !
      ! Output :
      !
      ! cf2mf - DLR coefficients -> Matsubara frequency grid values
      !           transform matrix


      implicit none
      integer rank,dlrmf(rank)
      real *8 dlrrf(rank)
      complex *16 cf2mf(rank,rank)

      complex *16, external :: kfunf_mf

      integer i,j

      ! Evaluated Matsubara frequency kernel at selected real
      ! frequencies and Matsubara frequencies 

      do j=1,rank
        do i=1,rank
          cf2mf(i,j) = kfunf_mf(dlrmf(i),dlrrf(j))
        enddo
      enddo

      end subroutine dlr_cf2mf




      subroutine dlr_convtens(beta,rank,dlrrf,dlrit,phi)

      ! Get tensor phi_{jkl} used to take a set of DLR coefficients to
      ! the matrix A of convolution by the corresponding DLR expansion.
      !
      ! A is applied to a vector of DLR coefficients, and returns the
      ! convolution at the DLR imaginary time nodes.
      !
      ! Given phi, the matrix A of convolution by a function with DLR
      ! coefficients rho_l is given by
      !
      ! A_jk = sum_l phi_jkl rho_l.
      !
      ! Input:
      !
      ! beta  - inverse temperature
      ! rank  - rank of DLR (# basis functions)
      ! dlrrf - selected real frequency nodes (omega points)
      ! dlrit - selected imaginary time nodes (tau points)
      !
      ! Output:
      !
      ! phi   - convolution tensor


      implicit none
      integer rank
      real *8 beta,dlrrf(rank),dlrit(rank)
      real *8 phi(rank*rank,rank)
      real *8, external :: kfun

      integer j,k,l,ier,maxrec,numint
      real *8 one,rint1,rint2
      real *8, external :: kfunf,kfunf_rel

      one = 1.0d0

      do l=1,rank
        do k=1,rank
          do j=1,rank

            if (k.ne.l) then

              phi((k-1)*rank+j,l) = (kfunf_rel(dlrit(j),dlrrf(l)) -&
                kfunf_rel(dlrit(j),dlrrf(k)))/(dlrrf(k)-dlrrf(l))

            else

              if (dlrit(j).gt.0.0d0) then

                phi((k-1)*rank+j,l) = (dlrit(j)-kfunf(1.0d0,dlrrf(k)))*&
                  kfunf_rel(dlrit(j),dlrrf(k))

              else

                phi((k-1)*rank+j,l) = (dlrit(j)+kfunf(0.0d0,dlrrf(k)))*&
                  kfunf_rel(dlrit(j),dlrrf(k))

              endif
            endif

          enddo
        enddo
      enddo

      phi = beta*phi

      end subroutine dlr_convtens


      subroutine dlr_convtens2(beta,rank,dlrrf,dlrit,it2cf,it2cfpiv,phi)

      ! Get tensor phi_{jkl} used to take a set of DLR coefficients to
      ! the matrix A of convolution by the corresponding DLR expansion.
      !
      ! A is applied to a vector of values of a function at the DLR
      ! imaginary time nodes, and returns the
      ! convolution at the DLR imaginary time nodes.
      !
      ! Given phi, the matrix A of convolution by a function with DLR
      ! coefficients rho_l is given by
      !
      ! A_jk = sum_l phi_jkl rho_l.
      !
      ! Input:
      !
      ! beta  - inverse temperature
      ! rank  - rank of DLR (# basis functions)
      ! dlrrf - selected real frequency nodes (omega points)
      ! dlrit - selected imaginary time nodes (tau points)
      !
      ! Output:
      !
      ! phi   - convolution tensor


      implicit none
      integer rank,it2cfpiv(rank)
      real *8 beta,dlrrf(rank),dlrit(rank),it2cf(rank,rank)
      real *8 phi(rank*rank,rank)
      real *8, external :: kfun

      integer j,k,l,ier,maxrec,numint,info
      real *8 one,rint1,rint2
      real *8, allocatable :: phitmp(:,:,:),phitmp2(:,:)
      real *8, external :: kfunf,kfunf_rel

      one = 1.0d0

      allocate(phitmp(rank,rank,rank),phitmp2(rank,rank*rank))

      do l=1,rank
        do k=1,rank
          do j=1,rank

            if (k.ne.l) then

              phitmp(j,k,l) = (kfunf_rel(dlrit(j),dlrrf(l)) -&
                kfunf_rel(dlrit(j),dlrrf(k)))/(dlrrf(k)-dlrrf(l))

            else

              if (dlrit(j).gt.0.0d0) then

                phitmp(j,k,l) = (dlrit(j)-kfunf(1.0d0,dlrrf(k)))*&
                  kfunf_rel(dlrit(j),dlrrf(k))

              else

                phitmp(j,k,l) = (dlrit(j)+kfunf(0.0d0,dlrrf(k)))*&
                  kfunf_rel(dlrit(j),dlrrf(k))

              endif
            endif

          enddo
        enddo
      enddo



      do l=1,rank
        do k=1,rank
          do j=1,rank
            phitmp2(k,(l-1)*rank+j) = phitmp(j,k,l)
          enddo
        enddo
      enddo
            
      call dgetrs('T',rank,rank*rank,it2cf,rank,it2cfpiv,phitmp2,rank,&
        info)

      do l=1,rank
        do k=1,rank
          do j=1,rank
            phitmp(j,k,l) = phitmp2(k,(l-1)*rank+j)
          enddo
        enddo
      enddo



      do l=1,rank
        do k=1,rank
          do j=1,rank
            phi((k-1)*rank+j,l) = phitmp(j,k,l)
          enddo
        enddo
      enddo


      phi = beta*phi

      end subroutine dlr_convtens2



      subroutine dlr_convtens3(beta,rank,dlrrf,dlrit,phi)

      ! Get tensor phi_{jkl} used to take the values of a DLR expansion at
      ! the DLR imaginary time nodes to the matrix A of convolution by
      ! the corresponding DLR expansion.
      !
      ! A is applied to a vector of values of a function at the DLR
      ! imaginary time nodes, and returns the
      ! convolution at the DLR imaginary time nodes.
      !
      ! Given phi, the matrix A of convolution by a function with values
      ! g_l at the DLR imaginary time nodes  is given by
      !
      ! A_jk = sum_l phi_jkl g_l.
      !
      ! We note that forming this tensor requires computations in
      ! quadruple precision arithmetic to circumvent a numerical
      ! instability, but dlrrf and dlrit do not need
      ! to be computed to quadruple precision, and the tensor phi is
      ! returned in double precision.
      !
      ! Input:
      !
      ! beta  - inverse temperature
      ! rank  - rank of DLR (# basis functions)
      ! dlrrf - selected real frequency nodes (omega points)
      ! dlrit - selected imaginary time nodes (tau points)
      !
      ! Output:
      !
      ! phi   - convolution tensor


      implicit none
      integer rank
      real *8 beta,dlrrf(rank),dlrit(rank)
      real *8 phi(rank*rank,rank)
      real *8, external :: kfun

      integer j,k,l,info
      integer, allocatable :: ipvt(:)
      real *16, allocatable :: phitmp(:,:,:),phitmp2(:,:),it2cf(:,:)
      real *16, allocatable :: qdlrit(:),qdlrrf(:)
      real *16, external :: qkfunf,qkfunf_rel


      allocate(qdlrit(rank),qdlrrf(rank))
      allocate(phitmp(rank,rank,rank),phitmp2(rank,rank*rank))
      allocate(it2cf(rank,rank),ipvt(rank))

      qdlrit = dlrit
      qdlrrf = dlrrf

      do l=1,rank
        do k=1,rank
          do j=1,rank

            if (k.ne.l) then

              phitmp(j,k,l) = (qkfunf_rel(qdlrit(j),qdlrrf(l)) -&
                qkfunf_rel(qdlrit(j),qdlrrf(k)))/(qdlrrf(k)-qdlrrf(l))

            else

              if (dlrit(j).gt.0.0d0) then

                phitmp(j,k,l) = (qdlrit(j)-qkfunf(1.0q0,qdlrrf(k)))*&
                  qkfunf_rel(qdlrit(j),qdlrrf(k))

              else

                phitmp(j,k,l) = (qdlrit(j)+qkfunf(0.0q0,qdlrrf(k)))*&
                  qkfunf_rel(qdlrit(j),qdlrrf(k))

              endif
            endif

          enddo
        enddo
      enddo



      do k=1,rank
        do j=1,rank
          it2cf(j,k) = qkfunf_rel(qdlrit(j),qdlrrf(k))
        enddo
      enddo

      call qgefa(it2cf,rank,rank,ipvt,info)




      do l=1,rank
        do k=1,rank
          do j=1,rank
            phitmp2(l,(k-1)*rank+j) = phitmp(j,k,l)
          enddo
        enddo
      enddo

      do k=1,rank*rank
        call qgesl(it2cf,rank,rank,ipvt,phitmp2(:,k),1)
      enddo
            
      do l=1,rank
        do k=1,rank
          do j=1,rank
            phitmp(j,k,l) = phitmp2(l,(k-1)*rank+j)
          enddo
        enddo
      enddo




      do l=1,rank
        do k=1,rank
          do j=1,rank
            phitmp2(k,(l-1)*rank+j) = phitmp(j,k,l)
          enddo
        enddo
      enddo

      do k=1,rank*rank
        call qgesl(it2cf,rank,rank,ipvt,phitmp2(:,k),1)
      enddo
            
      do l=1,rank
        do k=1,rank
          do j=1,rank
            phitmp(j,k,l) = phitmp2(k,(l-1)*rank+j)
          enddo
        enddo
      enddo



      do l=1,rank
        do k=1,rank
          do j=1,rank
            phi((k-1)*rank+j,l) = phitmp(j,k,l)
          enddo
        enddo
      enddo


      phi = beta*phi

      end subroutine dlr_convtens3




!      subroutine dlr_convmat(rank,phi,it2cf,it2cfpiv,g,gmat)
!
!      ! Get matrix of convolution by a DLR expansion G in the DLR basis
!      ! -- that is, the matrix that this subroutine produces takes the
!      ! DLR coefficient representation of a function f to the DLR
!      ! coefficient representation of the convolution
!      !
!      ! int_0^1 G(t-t') f(t') dt'.
!      !
!      ! Input:
!      !
!      ! rank      - rank of DLR (# basis functions)
!      ! phi       - convolution tensor
!      ! it2cf  - imaginary time grid values -> DLR coefficients
!      !               transform matrix in lapack LU storage format
!      ! it2cfpiv  - pivot matrix for it2cf in lapack LU storage
!      !               format
!      ! g         - DLR coefficients of a function G
!      !
!      ! Output:
!      !
!      ! gmat      - matrix of convolution by G in the DLR basis
!
!      implicit none
!      integer rank,it2cfpiv(rank)
!      real *8 phi(rank*rank,rank),it2cf(rank,rank),g(rank)
!      real *8 gmat(rank,rank)
!
!      integer i,j,info
!
!      call dgemv('N',rank*rank,rank,1.0d0,phi,rank*rank,g,1,0.0d0,&
!        gmat,1)
!
!      call dgetrs('N',rank,rank,it2cf,rank,it2cfpiv,gmat,rank,info)
!
!      end subroutine dlr_convmat


      subroutine dlr_convmat(rank,phi,it2cf,it2cfpiv,g,gmat)

      ! Get matrix of convolution by a DLR expansion G
      ! -- that is, the matrix that this subroutine produces takes the
      ! DLR imaginary time grid values of a function f to the DLR
      ! imaginary time grid values of the convolution
      !
      ! int_0^1 G(t-t') f(t') dt'.
      !
      ! Input:
      !
      ! rank      - rank of DLR (# basis functions)
      ! phi       - convolution tensor
      ! it2cf  - imaginary time grid values -> DLR coefficients
      !               transform matrix in lapack LU storage format
      ! it2cfpiv  - pivot matrix for it2cf in lapack LU storage
      !               format
      ! g         - DLR imaginary time values of a Green's function G
      !
      ! Output:
      !
      ! gmat      - matrix of convolution by G

      implicit none
      integer rank,it2cfpiv(rank)
      real *8 phi(rank*rank,rank),it2cf(rank,rank),g(rank)
      real *8 gmat(rank,rank)

      integer i,j,info
      real *8, allocatable :: gc(:)

      ! Get DLR coefficients of G

      allocate(gc(rank))

      call dlr_expnd(rank,it2cf,it2cfpiv,g,gc)

      ! Get convolution matrix taking coefficients -> values

      call dgemv('N',rank*rank,rank,1.0d0,phi,rank*rank,gc,1,0.0d0,&
        gmat,1)

      ! Precompose with matrix taking values -> coefficients

      gmat = transpose(gmat)

      call dgetrs('T',rank,rank,it2cf,rank,it2cfpiv,gmat,rank,info)

      gmat = transpose(gmat)

      end subroutine dlr_convmat



      subroutine dlr_convmat2(rank,phi,it2cf,it2cfpiv,g,gmat)

      ! Get matrix of convolution by a DLR expansion G
      ! -- that is, the matrix that this subroutine produces takes the
      ! DLR imaginary time grid values of a function f to the DLR
      ! imaginary time grid values of the convolution
      !
      ! int_0^1 G(t-t') f(t') dt'.
      !
      ! Input:
      !
      ! rank      - rank of DLR (# basis functions)
      ! phi       - convolution tensor
      ! it2cf  - imaginary time grid values -> DLR coefficients
      !               transform matrix in lapack LU storage format
      ! it2cfpiv  - pivot matrix for it2cf in lapack LU storage
      !               format
      ! g         - DLR imaginary time values of a Green's function G
      !
      ! Output:
      !
      ! gmat      - matrix of convolution by G

      implicit none
      integer rank,it2cfpiv(rank)
      real *8 phi(rank*rank,rank),it2cf(rank,rank),g(rank)
      real *8 gmat(rank,rank)

      integer info
      real *8, allocatable :: gc(:)

      ! Get DLR coefficients of G

      allocate(gc(rank))

      call dlr_expnd(rank,it2cf,it2cfpiv,g,gc)

      ! Get convolution matrix taking coefficients -> values

      call dgemv('N',rank*rank,rank,1.0d0,phi,rank*rank,gc,1,0.0d0,&
        gmat,1)


      end subroutine dlr_convmat2



      subroutine dlr_convmat3(rank,phi,g,gmat)

      ! Get matrix of convolution by a DLR expansion G
      ! -- that is, the matrix that this subroutine produces takes the
      ! DLR imaginary time grid values of a function f to the DLR
      ! imaginary time grid values of the convolution
      !
      ! int_0^1 G(t-t') f(t') dt'.
      !
      ! Input:
      !
      ! rank      - rank of DLR (# basis functions)
      ! phi       - convolution tensor
      ! it2cf  - imaginary time grid values -> DLR coefficients
      !               transform matrix in lapack LU storage format
      ! it2cfpiv  - pivot matrix for it2cf in lapack LU storage
      !               format
      ! g         - DLR imaginary time values of a Green's function G
      !
      ! Output:
      !
      ! gmat      - matrix of convolution by G

      implicit none
      integer rank
      real *8 phi(rank*rank,rank),g(rank),gmat(rank,rank)

      integer info


      call dgemv('N',rank*rank,rank,1.0d0,phi,rank*rank,g,1,0.0d0,&
        gmat,1)


      end subroutine dlr_convmat3


      subroutine dlr_buildit(lambda,eps,rank,dlrrf,dlrit)

      ! Build DLR by getting selected real frequencies, and build
      ! imaginary time grid.
      !
      ! Input:
      !
      ! lambda  - cutoff parameter
      ! eps     - DLR error tolerance
      ! rank    - max possible rank of DLR, defining input size of some
      !             arrays
      !
      ! Output :
      !
      ! rank    - rank of DLR (# basis functions)
      ! dlrrf   - selected real frequency nodes (omega points)
      ! dlrit   - selected imaginary time nodes (tau points)

      implicit none
      integer rank
      real *8 lambda,eps,dlrrf(rank),dlrit(rank)

      integer p,npt,npo,nt,no
      integer, allocatable :: oidx(:)
      real *8 kerr(2)
      real *8, allocatable :: kmat(:,:),t(:),om(:)


      ! Set parameters for the fine grid based on lambda

      call gridparams(lambda,p,npt,npo,nt,no)


      ! Get fine composite Chebyshev discretization of K(tau,omega)

      allocate(kmat(nt,no),t(nt),om(no))

      call kfine_cc(lambda,p,npt,npo,t,om,kmat,kerr)


      ! Select real frequency points for DLR basis

      rank = 500 ! Upper bound on possible rank

      allocate(oidx(rank))

      call dlr_rf(lambda,eps,nt,no,om,kmat,rank,dlrrf,oidx)


      ! Get DLR imaginary time grid

      call dlr_it(lambda,nt,no,t,kmat,rank,oidx,dlrit)

      end subroutine dlr_buildit


      subroutine dlr_buildmf(lambda,eps,nmax,rank,dlrrf,dlrmf)

      ! Build DLR by getting selected real frequencies, and build
      ! Matsubara frequency grid.
      !
      ! Input:
      !
      ! lambda  - cutoff parameter
      ! eps     - DLR error tolerance
      ! nmax    - Matsubara frequency cutoff
      ! rank    - max possible rank of DLR, defining input size of some
      !             arrays
      !
      ! Output :
      !
      ! rank    - rank of DLR (# basis functions)
      ! dlrrf   - selected real frequency nodes (omega points)
      ! dlrmf   - selected Matsubara frequency nodes

      implicit none
      integer nmax,rank,dlrmf(rank)
      real *8 lambda,eps,dlrrf(rank)

      integer p,npt,npo,nt,no
      integer, allocatable :: oidx(:)
      real *8 kerr(2)
      real *8, allocatable :: kmat(:,:),t(:),om(:)


      ! Set parameters for the fine grid based on lambda

      call gridparams(lambda,p,npt,npo,nt,no)


      ! Get fine composite Chebyshev discretization of K(tau,omega)

      allocate(kmat(nt,no),t(nt),om(no))

      call kfine_cc(lambda,p,npt,npo,t,om,kmat,kerr)


      ! Select real frequency points for DLR basis

      rank = 500 ! Upper bound on possible rank

      allocate(oidx(rank))

      call dlr_rf(lambda,eps,nt,no,om,kmat,rank,dlrrf,oidx)


      ! Get DLR Matsubara frequency grid

      call dlr_mf(nmax,rank,dlrrf,dlrmf)

      end subroutine dlr_buildmf





      subroutine eqpts_rel(n,t)

      ! Get equispaced points on [0,1] in relative format
      !
      ! Relative format means that points 0.5<t<1 are computed and stored as the negative
      ! distance from 1; that is, t* = t-1 in exact arithmetic. This is
      ! to used to maintain full relative precision for calculations
      ! with large lambda and small eps.
      !
      ! Input:
      !
      ! n - Number of points on [0,1]
      !
      ! Output :
      !
      ! t - n equispaced points on [0,1], including endpoints, in
      !       relative format

      implicit none
      integer n
      real *8 t(n)

      integer i

      do i=1,n-1

        if (i.le.n/2) then
          t(i) = (i-1)*1.0d0/(n-1)
        else
          t(i) = -(n-i)*1.0d0/(n-1)
        endif

      enddo

      t(n) = 1.0d0

      end subroutine eqpts_rel



      subroutine rel2abs(n,t,tabs)

      ! Convert points on [0,1] from relative format to absolute format
      !
      ! Relative format means that points 0.5<t<1 are computed and stored as the negative
      ! distance from 1; that is, t* = t-1 in exact arithmetic. This is
      ! to used to maintain full relative precision for calculations
      ! with large lambda and small eps. Absolute format means that all
      ! points are stored as normal.
      !
      ! Note: converting a point from relative to absolute format will,
      ! in general, constitute a loss of relative accuracy in the
      ! location of the point if the point is close to t = 1. For
      ! example, in three-digit arithmetic, the point t = 0.999111 could
      ! be stored as t* = -0.889e-3 in the relative format, but only as
      ! t = 0.999 in the absolute format.
      !
      ! Input:
      !
      ! n     - Number of points
      ! t     - Array of points on [0,1] stored in relative format
      !
      ! Output:
      !
      ! trel  - Array of points t in absolute format

      implicit none
      integer n
      real *8 t(n),tabs(n)

      integer i

      do i=1,n

        if (t(i).lt.0.0d0) then
          tabs(i) = t(i)+1.0d0
        else
          tabs(i) = t(i)
        endif

      enddo

      end subroutine rel2abs


      subroutine abs2rel(n,tabs,t)

      ! Convert a point on [0,1] from absolute format to relative format
      !
      ! Relative format means that points 0.5<t<1 are computed and stored as the negative
      ! distance from 1; that is, t* = t-1 in exact arithmetic. This is
      ! to used to maintain full relative precision for calculations
      ! with large lambda and small eps. Absolute format means that all
      ! points are stored as normal.
      !
      ! If the user wishes to specify points -- for example points at
      ! which to sample or evaluate a DLR -- in absolute format, those
      ! points must first be converted to relative format using this
      ! subroutine before using them as inputs into any other
      ! subroutines. Of course, in order to maintain full relative
      ! precision in all calculations, the user must specify points in
      ! relative format from the beginning, but in most cases at most a
      ! mild loss of accuracy will result from using the absolute
      ! format.
      !
      ! Input:
      !
      ! n     - Number of points
      ! tabs  - Array of points on [0,1] stored in absolute format
      !
      ! Output:
      !
      ! t     - Array of points t in relative format

      implicit none
      integer n
      real *8 t(n),tabs(n)

      integer i

      do i=1,n

        if (t(i).gt.0.5d0.and.t(i).lt.1.0d0) then
          t(i) = tabs(i)-1.0d0
        else
          t(i) = tabs(i)
        endif

      enddo

      end subroutine abs2rel
