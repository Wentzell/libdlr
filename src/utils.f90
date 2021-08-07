      !
      !
      ! This file contains basic utility routines used in the code
      !
      !





      !> Initialize subroutine barycheb for barycentric Lagrange
      !! interpolation at Chebyshev nodes.
      !!
      !! @param[in]   n   number of Chebyshev nodes
      !! @param[out]  xc  n Chebyshev nodes of the first kind 
      !! @param[out]  wc  barycentric interpolation weights at Chebyshev
      !!                    nodes of the first kind

      subroutine barychebinit(n,xc,wc)

      implicit none
      integer n
      real *8 xc(n),wc(n)

      integer j
      real *8 pi,c

      pi = 4*atan(1.0d0)

      do j=1,n
        c = (2.0d0*j-1)/(2*n)*pi
        xc(n-j+1) = cos(c)
        wc(n-j+1) = (1-2*mod(j-1,2))*sin(c)
        !w(j) = (-1)**(j-1)*sin(c)
      enddo

      end subroutine barychebinit





      !> Barycentric Lagrange interpolation at Chebyshev nodes of the
      !! first kind.
      !!
      !! @param[in]   n     number of Chebyshev nodes
      !! @param[in]   xc    n Chebyshev nodes of the first kind 
      !! @param[in]   wc    barycentric interpolation weights at
      !!                      Chebyshev nodes of the first kind
      !! @param[in]   x     evaluation point
      !! @param[in]   f     values of a function F at points xc
      !! @param[in]   val   value of interpolant of F at x

      subroutine barycheb(n,xc,wc,x,f,val)

      implicit none
      integer n
      real *8 x,f(n),wc(n),xc(n),val

      integer j
      real *8 dif,q,num,den

      do j=1,n
        if (x==xc(j)) then
          val = f(j)
          return
        endif
      enddo

      num = 0.0d0
      den = 0.0d0
      do j=1,n

        dif = x-xc(j)
        q = wc(j)/dif
        num = num + q*f(j)
        den = den + q

      enddo
      
      val = num/den

      end subroutine barycheb
