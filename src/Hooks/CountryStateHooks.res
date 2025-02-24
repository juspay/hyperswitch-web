open Country

let useCountryState = () =>
  {
    let setCountry = Recoil.useSetRecoilState(RecoilAtoms.countryAtom)
    let setState = Recoil.useSetRecoilState(RecoilAtoms.stateAtom)
    let logger = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)
    let {localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)

    React.useEffect(() => {
      let fetchData = async () => {
        let data = await S3Utils.getCountryStateData(~locale=localeString.locale, ~logger)
        setCountry(_ => data.countries)
        setState(_ => data.states)
      }

      fetchData()->ignore
      None
    }, [localeString.locale])
  }->ignore
