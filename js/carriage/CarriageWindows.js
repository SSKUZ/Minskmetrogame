export function buildCarriageWindows({carriage,box,side,z,carBlack,carGlass}){
  box(carriage,.026,.06,2.22,side*2.01,3.04,z,carBlack);
  box(carriage,.026,.06,2.22,side*2.01,1.99,z,carBlack);
  for(const edge of [-1,1])box(carriage,.027,1.08,.065,side*2.01,2.52,z+edge*1.08,carBlack);
  box(carriage,.012,1.0,2.08,side*2.00,2.52,z,carGlass);

}
