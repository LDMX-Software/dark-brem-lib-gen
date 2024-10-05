C     This File is Automatically generated by ALOHA 
C     The process calculated in this file is: 
C     (((Znuc**2*(aval**2*(- 2*MNul**2 -
C      2*P(-1,1)*P(-1,2))/(1+aval**2*(- 2*MNul**2 -
C      2*P(-1,1)*P(-1,2))))**2*(1/(1+(- 2*MNul**2 -
C      2*P(-1,1)*P(-1,2))/dval))**2)+Znuc*(apval**2*(- 2*MNul**2 -
C      2*P(-1,1)*P(-1,2))/(1+apval**2*(- 2*MNul**2 -
C      2*P(-1,1)*P(-1,2))))**2*((1+(- 2*MNul**2 -
C      2*P(-1,1)*P(-1,2))*inelastic1)/(1+(- 2*MNul**2 -
C      2*P(-1,1)*P(-1,2))*inelastic2)**4)**2)**0.5)*Gamma(3,2,1)
C     
      SUBROUTINE FF1P0_3(F1, F2, COUP, M3, W3,V3)
      IMPLICIT NONE
      INCLUDE '../MODEL/input.inc'
      INCLUDE '../MODEL/coupl.inc'
      COMPLEX*16 CI
      PARAMETER (CI=(0D0,1D0))
      COMPLEX*16 COUP
      COMPLEX*16 F1(*)
      COMPLEX*16 F2(*)
      COMPLEX*16 FCT0
      COMPLEX*16 FCT1
      COMPLEX*16 FCT10
      COMPLEX*16 FCT11
      COMPLEX*16 FCT12
      COMPLEX*16 FCT13
      COMPLEX*16 FCT14
      COMPLEX*16 FCT2
      COMPLEX*16 FCT3
      COMPLEX*16 FCT4
      COMPLEX*16 FCT5
      COMPLEX*16 FCT6
      COMPLEX*16 FCT7
      COMPLEX*16 FCT8
      COMPLEX*16 FCT9
      REAL*8 M3
      REAL*8 P1(0:3)
      REAL*8 P2(0:3)
      REAL*8 P3(0:3)
      COMPLEX*16 TMP0
      COMPLEX*16 V3(6)
      REAL*8 W3
      COMPLEX*16 DENOM
      P1(0) = DBLE(F1(1))
      P1(1) = DBLE(F1(2))
      P1(2) = DIMAG(F1(2))
      P1(3) = DIMAG(F1(1))
      P2(0) = DBLE(F2(1))
      P2(1) = DBLE(F2(2))
      P2(2) = DIMAG(F2(2))
      P2(3) = DIMAG(F2(1))
      V3(1) = +F1(1)+F2(1)
      V3(2) = +F1(2)+F2(2)
      P3(0) = -DBLE(V3(1))
      P3(1) = -DBLE(V3(2))
      P3(2) = -DIMAG(V3(2))
      P3(3) = -DIMAG(V3(1))
      TMP0 = (P2(0)*P1(0)-P2(1)*P1(1)-P2(2)*P1(2)-P2(3)*P1(3))
      FCT0 = (MDL_ZNUC)**(2D0)
      FCT1 = (MDL_AVAL)**(2D0)
      FCT2 = (MDL_MNUL)**(2D0)
      FCT3 = 1D0/((-2D0)*(FCT1*(FCT2+TMP0)+ -1D0/2D0))
      FCT4 = (-2D0 * FCT1*FCT3*(FCT2+TMP0))**(2D0)
      FCT5 = 1D0/(MDL_DVAL)
      FCT6 = 1D0/((-2D0)*(FCT5*(FCT2+TMP0)+ -1D0/2D0))
      FCT7 = (FCT6)**(2D0)
      FCT8 = (MDL_APVAL)**(2D0)
      FCT9 = 1D0/((-2D0)*(FCT8*(FCT2+TMP0)+ -1D0/2D0))
      FCT10 = (-2D0 * FCT8*FCT9*(FCT2+TMP0))**(2D0)
      FCT11 = ((-2D0)*(MDL_INELASTIC2*(FCT2+TMP0)+ -1D0/2D0))**(4D0)
      FCT12 = 1D0/(FCT11)
      FCT13 = (-2D0 * FCT12*(MDL_INELASTIC1*(FCT2+TMP0)+ -1D0/2D0))*
     $ *(2D0)
      FCT14 = ((FCT7*FCT4*FCT0+MDL_ZNUC*FCT13*FCT10))**(1D0/2D0)
      DENOM = COUP/(P3(0)**2-P3(1)**2-P3(2)**2-P3(3)**2 - M3 * (M3 -CI
     $ * W3))
      V3(3)= DENOM*(-CI )* FCT14*(F2(5)*F1(3)+F2(6)*F1(4)+F2(3)*F1(5)
     $ +F2(4)*F1(6))
      V3(4)= DENOM*(-CI )* FCT14*(-F2(6)*F1(3)-F2(5)*F1(4)+F2(4)*F1(5)
     $ +F2(3)*F1(6))
      V3(5)= DENOM*(-CI )* FCT14*(-CI*(F2(6)*F1(3)+F2(3)*F1(6))+CI
     $ *(F2(5)*F1(4)+F2(4)*F1(5)))
      V3(6)= DENOM*(-CI )* FCT14*(-F2(5)*F1(3)-F2(4)*F1(6)+F2(6)*F1(4)
     $ +F2(3)*F1(5))
      END


